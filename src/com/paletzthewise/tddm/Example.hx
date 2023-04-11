package com.paletzthewise.tddm;

import com.paletzthewise.elite.EdsmToEddbTranslator;
import haxe.CallStack;
import haxe.Json;
import haxe.Timer;
import php.Exception;
import php.Global;
import php.Const;
import php.SuperGlobal;
import com.paletzthewise.elite.EddbJson;
import com.paletzthewise.elite.EdsmJson;
import com.paletzthewise.tddm.TempFile;
import com.paletzthewise.tddm.PhpTools;
import com.paletzthewise.tddm.TransformativeDataDumpMirror;

/** PHP transformative data dump mirror example
 * 
 * The source URL is defined by the url variable, by default it points to the edsm.systemsPopulated.sample.json.gz file deployed in the same folder as index.php. Use https://www.edsm.net/dump/systemsPopulated.json.gz for the real data dump.
 * 
 * Renders a data dump file depending on the arguments:
 *   * ?example=id              - Renders the remote as is.
 *   * ?example=eddb&filename=x - Translates the edsm file in to eddb-style systems/stations/factions files. x must be one of the following "systems_populated.sample.json.gz", "stations.sample.json.gz" or "factions.sample.json.gz".
**/
class Example
{
	public static function main()
	{
		try 
		{
			// Url to the "remote" dump file, this example uses a sample in its own folder.
			var url = PhpTools.getUrlToSelfFolder() + "edsm.systemsPopulated.sample.json.gz";
			
			var mainFolder = StringTools.replace( Global.dirname( Const.__FILE__ ), ['','com','paletzthewise','elite','tddm'].join(Const.DIRECTORY_SEPARATOR), "" ); // shave off the package
			var cacheDirectory = mainFolder.substring( 0, mainFolder.length - 4 ); // Haxe generates all classes into the lib/ subfolder
			
			if ( !Global.array_key_exists( 'example', SuperGlobal._GET ) )
			{
				Global.echo( "The example parameter is not set." );
				return;
			}
			
			switch ( SuperGlobal._GET['example'] )
			{
			case "id":
				var dataFilename = "edsm.systemsPopulated.id.json.gz";
				var utilityFilenamePrefix = "id";
				var mirror = new TransformativeDataDumpMirror( url, cacheDirectory, utilityFilenamePrefix );
				mirror.render( 
					dataFilename,
					function ( rawRemoteFile : TempFile )
					{
						rawRemoteFile.persist( cacheDirectory + Const.DIRECTORY_SEPARATOR + dataFilename ); // We want the source as is, the temp file will do.
					}
				);
			case "eddb":
				var utilityFilenamePrefix = "eddb";
				
				if ( !Global.array_key_exists( 'filename', SuperGlobal._GET ) )
				{
					Global.echo( "The filename parameter is not set." );
					return;
				}
				
				var lockFilename = "eddb.sample.lock";
				
				var dataFilenameSystems = "systems_populated.json.gz";
				var dataFilenameStations = "stations.json.gz";
				var dataFilenameFactions = "factions.json.gz";
				
				var dataFilename = null;
				if ( [dataFilenameSystems, dataFilenameStations, dataFilenameFactions].contains( SuperGlobal._GET['filename'] ) )
				{
					dataFilename = SuperGlobal._GET['filename'];
					
				}
				else
				{
					Global.echo( "Invalid value of the filename parameter." );
					return;
				}
				
				var mirror = new TransformativeDataDumpMirror( url, cacheDirectory, utilityFilenamePrefix );
				mirror.render( dataFilename, function ( rawRemoteFile : TempFile ) {
					TempFile.with( mirror.getTempDirectory(), "systems", "wb", true, function ( systemsTempFile : TempFile ) {
						TempFile.with( mirror.getTempDirectory(), "stations", "wb", true,	function ( stationsTempFile : TempFile ) {
							TempFile.with( mirror.getTempDirectory(), "factions", "wb", true, function ( factionsTempFile : TempFile ) {
								
								EdsmToEddbSystemTranslator.transform(
									()->rawRemoteFile.readLine(),
									systemsString->systemsTempFile.write( systemsString ),
									stationsString->stationsTempFile.write( stationsString ),
									factionsString->factionsTempFile.write( factionsString ),
									issue->PhpTools.log( LogLevel.NOTICE, issue )
								);
								
								systemsTempFile.persist( cacheDirectory + Const.DIRECTORY_SEPARATOR + dataFilenameSystems );
								stationsTempFile.persist( cacheDirectory + Const.DIRECTORY_SEPARATOR + dataFilenameStations );
								factionsTempFile.persist( cacheDirectory + Const.DIRECTORY_SEPARATOR + dataFilenameFactions );
							} ); 
						} ); 
					} );
				} );
				
			default:
				Global.echo("Invalid value of the example parameter");
			}
		}
		catch (e : Exception)
		{
			PhpTools.log( LogLevel.CRIT, "Uncaught exception: " + e.getMessage() + " Stack trace: " + StringTools.replace( e.getTraceAsString(), "\n", " | ") );
			Global.http_response_code(500);			
		}
		catch (e)
		{
			PhpTools.log( LogLevel.CRIT, "Uncaught simple exception: " + Std.string(e) );
			Global.http_response_code(500);
		}
	}
}