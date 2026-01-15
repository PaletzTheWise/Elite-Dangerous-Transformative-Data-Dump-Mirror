// Copyright 2023 Paletz
//
// This file is part of Elite Dangerous Transformative Data Dump Mirror (TDDM)
//
// TDDM is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
//
// TDDM is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License along with Foobar. If not, see <https://www.gnu.org/licenses/>.

package com.paletzthewise.tddm;
import com.paletzthewise.tddm.TempFile;
import com.paletzthewise.tddm.FileLock;
import php.Resource;
import php.Global;
import php.Const;
import php.Exception;
import com.paletzthewise.tddm.PhpTools;
import com.paletzthewise.tddm.DirectoryTraversal;

enum MirrorState
{
	Fresh;
	Cached;
}

enum GenerationMaturity
{
	// in ascending order
	None;
	Downloaded;
	Transformed;
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
	var utilityPrefix : String;
	var tempDirectory : String;
	var generationsDirectory : String;
	var generationsAddRemoveLockFilePath : String;

	var checkInterval : Int;
	var tempFileLongevity: Int;

	/** Constructor
	 * 
	 * @param url URL to the remote data dump source.
	 * @param cacheDirectory Filesystem path to the directory where the cached files and utility files are to be located
	**/
	public function new ( url : String, cacheDirectory : String, utilityPrefix : String, checkInterval : Int, tempFileLongevity : Int )
	{
		PhpTools.log( LogLevel.INFO, 'TDDM: Configuring for url="$url", dir="$cacheDirectory", prefix="$utilityPrefix"' );
		
		this.url = url;
		this.cacheDirectory = cacheDirectory;
		this.utilityPrefix = utilityPrefix;
		this.tempDirectory = cacheDirectory + Const.DIRECTORY_SEPARATOR + utilityPrefix + "Temp";
		this.generationsDirectory = cacheDirectory + Const.DIRECTORY_SEPARATOR + utilityPrefix + "Generations";
		this.generationsAddRemoveLockFilePath = generationsDirectory + Const.DIRECTORY_SEPARATOR + "addRemove.lock";

		this.checkInterval = checkInterval;
		this.tempFileLongevity = tempFileLongevity;

		PhpTools.ensureDirectory(tempDirectory);
		PhpTools.ensureDirectory(generationsDirectory);
	}

	private function getModTimePath(generationPath : String, maturity : GenerationMaturity) : String
	{
		return generationPath + Const.DIRECTORY_SEPARATOR + maturity.getName() + ".modTime";
	}

	private function getCheckTimePath(generationPath : String) : String
	{
		return generationPath + Const.DIRECTORY_SEPARATOR + GenerationMaturity.Downloaded.getName() + ".checkTime";	
	}

	private function getDownloadPath(generationPath : String) : String
	{
		return generationPath + Const.DIRECTORY_SEPARATOR + GenerationMaturity.Downloaded.getName() + ".file";	
	}

	private function getDownloadLockPath(generationPath : String) : String
	{
		return generationPath + Const.DIRECTORY_SEPARATOR + "Download.lock";	
	}

	private function getTransformationLockPath(generationPath : String) : String
	{
		return generationPath + Const.DIRECTORY_SEPARATOR + "Transformation.lock";	
	}

	private function getUsageTimePath(generationPath : String) : String
	{
		return generationPath + Const.DIRECTORY_SEPARATOR + "usedTime";	
	}

	public function getTempDirectory()
	{
		return tempDirectory;
	}

	private function cleanUpTemp() : Void
	{
		DirectoryTraversal.with(
			tempDirectory,
			function (directoryTraversal : DirectoryTraversal)
			{
				directoryTraversal.for_each_path(
					function (path : String)
					{
						// There should not be any directories.
						var usedTime = Math.max(PhpTools.getModifiedTime(path), PhpTools.getAccessTime(path));

						if ( usedTime + tempFileLongevity < Global.time() )
						{
							Global.unlink(path);
						}
					}
				);
			}
		);
	}

	/** Create a new generations directory
	 * 
	 * The generationsAddRemoveLock must be acquired before calling this method.
	 */
	private function createGenerationDirectory() : String
	{
		var path = PhpTools.makeRandomDir( generationsDirectory, "gen" );
		
		if ( path == null )
		{
			throw new  Exception( 'Failed to create temp directory starting with "gen" in $generationsDirectory.' );	
		}

		Global.touch(getModTimePath(path, GenerationMaturity.None));
		Global.touch(getUsageTimePath(path));

		PhpTools.log( LogLevel.NOTICE, 'TDDM: Made new generation directory $path.' );

		return path;
	}

	private function getGenerationState(generationPath : String) : {maturity : GenerationMaturity, modTime : Int}
	{
		for ( maturity in [ GenerationMaturity.Transformed, GenerationMaturity.Downloaded, GenerationMaturity.None ] )
		{
			var modTimePath = getModTimePath(generationPath, maturity);

			if (Global.is_file(modTimePath))
			{
				return (
					{
						maturity : maturity,
						modTime : PhpTools.getModifiedTime(modTimePath)
					}
				);
			}
		}
		return {maturity : None, modTime : null}
	}

	private function findNewestGeneration(minMaturity : GenerationMaturity) : {directory : String, maturity : GenerationMaturity, modTime : Int}
	{
		var bestGeneration = (
			{
				directory : null,
				maturity : null,
				modTime : null, 
			}
		);
		
		DirectoryTraversal.with(
			generationsDirectory,
			function (directoryTraversal : DirectoryTraversal)
			{
				directoryTraversal.for_each_path(
					function (generationDirectory : String)
					{
						if (Global.is_dir(generationDirectory))
						{
							var state = getGenerationState(generationDirectory);
							if (
								state.maturity.getIndex() >= minMaturity.getIndex()
								&&
							    (
									bestGeneration.maturity == null
									||
									bestGeneration.modTime < state.modTime
								)
							   )
							{
								bestGeneration = (
									{
										directory : generationDirectory,
										maturity : state.maturity,
										modTime : state.modTime,
									}
								);
							}
						}
					}
				);
			}
		);
		
		if ( bestGeneration.maturity != null )
		{
			Global.touch(getUsageTimePath(bestGeneration.directory));
		}

		return bestGeneration;
	}

	private function cleanUpGenerations() : Void
	{
		// Find automatically touches usage time file.
		findNewestGeneration(GenerationMaturity.Downloaded);
		findNewestGeneration(GenerationMaturity.Transformed);

		FileLock.with(
			generationsAddRemoveLockFilePath,
			function () 
			{
				DirectoryTraversal.with(
					generationsDirectory,
					function (directoryTraversal : DirectoryTraversal)
					{
						directoryTraversal.for_each_path(
							function (generationDirectory : String)
							{
								if (!Global.is_dir(generationDirectory)
									||
									PhpTools.getModifiedTime(getUsageTimePath(generationDirectory)) + tempFileLongevity > Global.time()) // Somewhat freshly used, do not remove.
								{
									return;
								}

								PhpTools.recursiveRemove(generationDirectory);
							}
						);
					}
				);
			}
		);
	}

	public function cleanUp() : Void
	{
		cleanUpTemp();
		cleanUpGenerations();
	}

	private function isReadyToCheckRemote( generationPath: String ) : Bool
	{
		// The cached file(s) must exist if the modtime file exists, otherwise somebody screwed up
		var checkFilePath = getCheckTimePath(generationPath);

		return (
			!Global.file_exists(checkFilePath)
			||
			PhpTools.getModifiedTime(checkFilePath) + checkInterval <= Global.time()
		);
	}

	private function isRemoteNewer( generationPath: String ) : Bool
	{
		PhpTools.log( LogLevel.INFO, 'TDDM: Checking $url' );

		var modTimeFilePath = getModTimePath(generationPath, GenerationMaturity.Downloaded);

		if ( !Global.file_exists(modTimeFilePath) )
		{
			PhpTools.log( LogLevel.NOTICE, 'TDDM: Modtime file "$modTimeFilePath" does not exist.' );
			return false;
		}
		
		var cachedFileTimestamp = PhpTools.getModifiedTime( modTimeFilePath );
		
		var setOptLastModifiedOnly = function ( curlHandle : Resource )
		{
			if ( !PhpToolsGlobal.curl_setopt( curlHandle, PhpToolsConst.CURLOPT_NOBODY, true ) )
			{
				throw new Exception( "TDDM: Couldn't set curl optional parameter NOBODY" );
			}
		}
		
		var urlTimestamp = accessUrl(setOptLastModifiedOnly).lastModified;
		
		if ( urlTimestamp <= cachedFileTimestamp )
		{
			Global.touch( getCheckTimePath(generationPath) );
			return false;
		}
		else
		{
			PhpTools.log( LogLevel.NOTICE, 'TDDM: $url is newer.' );
			return true;
		}

	}

	private function isReadyToCheckAndRemoteNewer( generationPath : String ) : Bool
	{
		return ( isReadyToCheckRemote(generationPath) && isRemoteNewer(generationPath) );
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

	private function download( generationDirectory : String )
	{
		FileLock.with(
			getDownloadLockPath(generationDirectory),
			function () 
			{
				if ( !isReadyToCheckRemote(findNewestGeneration(GenerationMaturity.Downloaded).directory) )
				{
					return; // Another thread beat us to it.
				}

				TempFile.with(
					tempDirectory,
					'remote',
					"wb",
					false,
					function ( tempFile : TempFile ) 
					{
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
						
						tempFile.persist(getDownloadPath(generationDirectory));
						
						Global.touch( getModTimePath(generationDirectory, GenerationMaturity.Downloaded), remoteLastModified );
						Global.touch( getCheckTimePath(generationDirectory) );
					} 
				);
			} 
		);
	}

	private function newGenerationRequiredForDownload( generation : {directory : String, maturity : GenerationMaturity, modTime : Int} ) : Bool
	{
		return (
			generation.maturity == null
			||
			( [GenerationMaturity.Downloaded, GenerationMaturity.Transformed].contains(generation.maturity) && isReadyToCheckAndRemoteNewer(generation.directory) )
		);
	}

	public function checkDownload()
	{
		cleanUp();

		var newestGeneration = findNewestGeneration(GenerationMaturity.None);
		
		if ( newestGeneration.maturity == GenerationMaturity.None )
		{
			PhpTools.log( LogLevel.NOTICE, 'TDDM: Download conditions met for existing generation: ${newestGeneration.directory}' );
			download(newestGeneration.directory);
		}
		else if ( newGenerationRequiredForDownload(newestGeneration) )
		{

			FileLock.with(
				generationsAddRemoveLockFilePath,
				function () 
				{
					// check if anyone else beat us to it
					newestGeneration = findNewestGeneration(GenerationMaturity.None);

					if ( newGenerationRequiredForDownload(newestGeneration) )
					{
						PhpTools.log( LogLevel.NOTICE, 'TDDM: Download conditions met for a new generation.' );
						createGenerationDirectory();
					}
				}
			);

			newestGeneration = findNewestGeneration(GenerationMaturity.None);
			
			if (newestGeneration.maturity == GenerationMaturity.None)
			{
				PhpTools.log( LogLevel.NOTICE, 'TDDM: Download conditions met for freshly created generation: ${newestGeneration.directory}' );
				download(newestGeneration.directory);
			}
		}
	}

	private function transformDownload(generationDirectory : String, transform : (FileRead,String)->Void)
	{
		FileLock.with(
			getTransformationLockPath(generationDirectory),
			function () 
			{
				if ( findNewestGeneration(GenerationMaturity.Downloaded).maturity == GenerationMaturity.Transformed)
				{
					return; // Another thread beat us to it.
				}

				FileRead.with(
					getDownloadPath(generationDirectory),
					"rb",
					true,
					function (fileRead : FileRead)
					{
						transform(fileRead, generationDirectory);

						var downloadModTime = PhpTools.getModifiedTime( getModTimePath(generationDirectory, GenerationMaturity.Downloaded) );
						Global.touch( getModTimePath(generationDirectory, GenerationMaturity.Transformed), downloadModTime);
					}
				);
			} 
		);
	}

	public function checkTransformation(transform : (FileRead,String)->Void)
	{
		cleanUp();

		var newestDownloadGeneration = findNewestGeneration(GenerationMaturity.Downloaded);
		
		if ( newestDownloadGeneration.maturity == GenerationMaturity.Downloaded )
		{
			PhpTools.log( LogLevel.NOTICE, 'TDDM: Transformation conditions met for ${newestDownloadGeneration.directory}.' );
			transformDownload(newestDownloadGeneration.directory, transform);
		}
	}

	public function outputTransformed( dataFilename : String, allowRefresh : Bool, allowInitialize : Bool, transform : (FileRead,String)->Void)
	{
		cleanUp();

		if (allowRefresh 
			||
			( allowInitialize && findNewestGeneration(GenerationMaturity.Transformed).maturity != GenerationMaturity.Transformed ) ) 
		{
			checkDownload();
			checkTransformation(transform);
		}
		
		var generation = findNewestGeneration(GenerationMaturity.Transformed);

		if ( generation.maturity != GenerationMaturity.Transformed )
		{
			throw new Exception('TDDM: No transformed data available.');
		}

		var dataFilePath = generation.directory + Const.DIRECTORY_SEPARATOR + dataFilename;
		
		var timestamp = PhpTools.getModifiedTime( getModTimePath(generation.directory, GenerationMaturity.Transformed) );
		var gmdate = PhpTools.checkOutcome( Global.gmdate("D, d M Y H:i:s", timestamp), "TDDM: Failed to format date." );
		
		Global.header( 'Content-Type: application/json; charset=utf-8' );
		Global.header( 'Content-Encoding: gzip');
		Global.header( 'Content-Disposition: attachment; filename="$dataFilename"');
		Global.header( 'Last-Modified: $gmdate GMT');
		Global.header( 'Cache-Control: no-cache' );
		PhpToolsGlobal.readfile( dataFilePath );
	}
}