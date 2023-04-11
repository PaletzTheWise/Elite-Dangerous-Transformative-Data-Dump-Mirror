package com.paletzthewise.tddm;
import com.paletzthewise.tddm.TempFile;
import com.paletzthewise.tddm.FileLock;
import php.Resource;
import php.Global;
import php.Const;
import php.Exception;
import com.paletzthewise.tddm.PhpTools
;
enum MirrorState
{
	Fresh;
	Cached;
}

/** A data dump mirror that transforms the data structure arbitrarily or not at all.
 *
 * Assumptions:
 *   * Data originate from a single source http/https URL
 *   * Source is compressed/binary
 *   * Source response header includes accurate modified time
 *   * The output of the transformation is one or more files, for the render() method, the output includes the file to be rendered.
*/
class TransformativeDataDumpMirror
{
	var url : String; // url to remote source of raw data
	var cacheDirectory : String; // directory containing cached data file
	var tempDirectory : String;
	
	// Utility file names, if multiple files are cached from single url download then they all must use the same utiliy filenames
	var lockFilepath : String; // name of the file to be used for locking for synchronization
	var checkFilepath : String; // name of the file to be used for tracking when the source was last checked for updates
	var modtimeFilepath : String; // name of the file to be used for tracking source mod time
	
	/** Constructor
	 * 
	 * @param url URL to the remote data dump source.
	 * @param cacheDirectory Filesystem path to the directory where the cached files and utility files are to be located
	 * @param utilityPrefix File/directory prefix to be used for internal files
	**/
	public function new ( url : String, cacheDirectory : String, utilityPrefix : String )
	{
		PhpTools.log( LogLevel.INFO, 'TDDM: Initializing for url="$url", dir="$cacheDirectory", prefix="$utilityPrefix"' );
		
		this.url = url;
		this.cacheDirectory = cacheDirectory;
		this.tempDirectory = cacheDirectory + Const.DIRECTORY_SEPARATOR + utilityPrefix + "Temp";
		this.lockFilepath = cacheDirectory + Const.DIRECTORY_SEPARATOR + utilityPrefix + ".lock";
		this.checkFilepath = cacheDirectory + Const.DIRECTORY_SEPARATOR + utilityPrefix + ".check";
		this.modtimeFilepath = cacheDirectory + Const.DIRECTORY_SEPARATOR + utilityPrefix + ".modtime";
		
		if ( !Global.is_dir( tempDirectory ) && !Global.mkdir( tempDirectory ) )
		{
			throw new Exception('TDDM: Failed to create temp directory $tempDirectory.');
		}
	}
	
	public function render( dataFilename : String, transform : TempFile->Void )
	{
		var mirrorState = ensureCacheUpToDate( dataFilename, transform );
		sendCached( dataFilename, mirrorState );
	}
	
	public function ensureCacheUpToDate( dataFilename : String, transform : TempFile->Void )
	{
		if ( isCacheUpToDate() )
		{
			return MirrorState.Cached;
		}
		else
		{
			updateCache( transform );
			return MirrorState.Fresh;
		}
	}
	
	public function getTempDirectory()
	{
		return tempDirectory;
	}
	
	private function getModifiedTime( filePath : String ) : Int
	{
		var filemtimeResult = Global.filemtime(filePath);
		
		if ( ! filemtimeResult is Int || filemtimeResult == -1 )
		{
			throw new Exception( 'TDDM: Couldn\'t read modtime of $filePath' );
		}
		
		return cast( filemtimeResult );
	}
	
	private function isCacheUpToDate( assumeRemoteNewer : Bool = false ) : Bool
	{
		var maxCacheAge = 5 * 60;
		
		if ( Global.file_exists(modtimeFilepath) ) // The cached file(s) must exist if the modtime file exists, otherwise somebody screwed up
		{
			// Only check the URL if we did not in a while.
			if ( Global.file_exists(checkFilepath) && getModifiedTime(checkFilepath) + maxCacheAge > Global.time() )
			{
				return true;
			}
			else
			{
				if ( assumeRemoteNewer )
				{
					return false;
				}
				
				var cachedFileTimestamp = getModifiedTime( modtimeFilepath );
				
				var setOptLastModifiedOnly = function ( curlHandle : Resource )
				{
					if ( !PhpToolsGlobal.curl_setopt( curlHandle, PhpToolsConst.CURLOPT_NOBODY, true ) )
					{
						throw new Exception( "TDDM: Couldn't set curl optional parameter NOBODY" );
					}
				}
				
				PhpTools.log( LogLevel.INFO, 'TDDM: Checking $url' );
				var urlTimestamp = accessUrl(setOptLastModifiedOnly).lastModified;
				
				if ( urlTimestamp <= cachedFileTimestamp )
				{
					Global.touch( checkFilepath );
					return true;
				}
			}
		}
		
		return false;
	}
	
	private function accessUrl( curlOptSetter : Resource->Void ) : { lastModified : Int }
	{
		return PhpTools.with (
			() -> PhpTools.checkOutcome( PhpToolsGlobal.curl_init(url), "TDDM: Couldn't curl_init the dump" ),
			function (curlHandle) 
			{
				if ( !PhpToolsGlobal.curl_setopt( curlHandle, PhpToolsConst.CURLOPT_FILETIME, true ) )
				{
					throw new Exception( "TDDM: Couldn't set curl optional parameters" );
				}
				
				curlOptSetter( curlHandle );
				
				var data = PhpTools.checkOutcome( PhpToolsGlobal.curl_exec(curlHandle), "TDDM: Couldn't download the dump." );
				
				var curlRetval = PhpToolsGlobal.curl_getinfo( curlHandle, PhpToolsConst.CURLINFO_FILETIME );
				
				if ( ! curlRetval is Int || cast( curlRetval, Int ) == -1 )
				{
					throw new Exception( "TDDM: Couldn't curl getinfo file timestamp." );
				}
				
				var urlTimestamp : Int = cast( curlRetval );
				
				return (
					{ 
						lastModified : urlTimestamp,
						data : data
					}
				);
			},
			(curlHandle) -> PhpToolsGlobal.curl_close(curlHandle)
		);
	}
	
	private function updateCache( transform : TempFile->Void )
	{
		FileLock.with (	lockFilepath,	function ()	{
			
			// check again, maybe update was already in progress
			if ( isCacheUpToDate( true ) )
			{
				return; // someone else beat us to it
			}
			
			TempFile.with ( tempDirectory, 'remote', "wb", false, function ( tempFile : TempFile ) {
				
				// save the url file into temp as is, including compression
				
				var setCurlOptFileOut = function ( curlHandle : Resource )
				{
					if ( !PhpToolsGlobal.curl_setopt( curlHandle, PhpToolsConst.CURLOPT_RETURNTRANSFER, 1 ) )
					{
						throw new Exception( "TDDM: Couldn't set CURLOPT_RETURNTRANSFER." );
					}
					if ( !PhpToolsGlobal.curl_setopt( curlHandle, PhpToolsConst.CURLOPT_FILE, tempFile.getHandle() ) )
					{
						throw new Exception( "TDDM: Couldn't set CURLOPT_FILE." );
					}
				}
				
				PhpTools.log( LogLevel.NOTICE, 'TDDM: Attempting to download $url' );
				var remoteLastModified = accessUrl( setCurlOptFileOut ).lastModified;
				
				tempFile.reopen( "rb", true );
				
				// do whatever needs to be done, to trasnform the raw remote into cached data
				
				transform( tempFile );
				
				Global.touch( modtimeFilepath, remoteLastModified );
				Global.touch( checkFilepath );
			} );
		} );
	}
	
	private function sendCached( dataFilename : String, mirrorState : MirrorState )
	{
		var dataFilePath = cacheDirectory + Const.DIRECTORY_SEPARATOR + dataFilename;
		if ( ! Global.file_exists(dataFilePath) )
		{
			throw new Exception('TDDM: Can\'t send cached data file $dataFilename, it does not exist.');
		}
		
		var timestamp = getModifiedTime( modtimeFilepath );
		var gmdate = PhpTools.checkOutcome( Global.gmdate("D, d M Y H:i:s", timestamp), "TDDM: Failed to format date." );
		
		Global.header( 'Content-Type: application/json; charset=utf-8' );
		Global.header( 'Content-Encoding: gzip');
		Global.header( 'Content-Disposition: attachment; filename="$dataFilename"');
		switch ( mirrorState )
		{
		case MirrorState.Fresh:
			Global.header( 'ed-transformative-data-dump-mirror-state: fresh');
		case MirrorState.Cached:
			Global.header( 'ed-transformative-data-dump-mirror-state: cached');
		default:
			throw new Exception( "Unrecognized MirrorState" );
		}
		Global.header( 'Last-Modified: $gmdate GMT');
		Global.header( 'Cache-Control: no-cache' );
		PhpToolsGlobal.readfile( dataFilePath );
	}
}