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
 * The source URL is defined by the url variable, by default it points to https://www.edsm.net/dump/systemsPopulated.json.gz. A small static sample is also available as edsm.systemsPopulated.sample.json.gz.
 * 
 * Renders a data dump file depending on the arguments:
 *   * ?example=id              - Renders the remote as is.
 *   * ?example=eddb&filename=x - Translates the edsm file in to eddb-style systems/stations/factions files. x must be one of the following "systems_populated.json", "stations.json" or "factions.json".
**/
class Example
{
	public static function main()
	{
		try 
		{
			// Url to the "remote" dump file, this example uses a sample in its own folder.
			var url = "https://www.edsm.net/dump/systemsPopulated.json.gz";
			//var url = PhpTools.getUrlToSelfFolder() + "edsm.systemsPopulated.sample.json.gz"; // small static sample alternative
			
			var mainFolder = StringTools.replace( Global.dirname( Const.__FILE__ ), ['','com','paletzthewise','tddm'].join(Const.DIRECTORY_SEPARATOR), "" ); // shave off the package
			var cacheDirectory = mainFolder.substring( 0, mainFolder.length - 4 ); // Haxe generates all classes into the lib/ subfolder
			
			var help = (
				"<br/>Usage:<br/>"
				+ '<a href="index.php?example=id">index.php?example=id</a> renders the remote as is.<br/>'
				+ 'EDSM format transformed to EDDB format: edsm file in to eddb-style systems/stations/factions files. x must be one of the following "systems_populated.json", "stations.json" or "factions.json".<br/>'
				+ '<a href="index.php?example=eddb&filename=systems_populated.json">index.php?example=eddb&filename=systems_populated.json</a><br/>'
				+ '<a href="index.php?example=eddb&filename=stations.json">index.php?example=eddb&filename=stations.json</a><br/>'
				+ '<a href="index.php?example=eddb&filename=factions.json">index.php?example=eddb&filename=factions.json</a><br/>'
			);
			
			if ( !Global.array_key_exists( 'example', SuperGlobal._GET ) )
			{
				Global.echo( "The example parameter is not set." + help );
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
					Global.echo( "The filename parameter is not set." + help );
					return;
				}
				
				var lockFilename = "eddb.sample.lock";
				
				var dataFilenameSystems = "systems_populated.json";
				var dataFilenameStations = "stations.json";
				var dataFilenameFactions = "factions.json";
				
				var dataFilename = null;
				if ( [dataFilenameSystems, dataFilenameStations, dataFilenameFactions].contains( SuperGlobal._GET['filename'] ) )
				{
					dataFilename = SuperGlobal._GET['filename'];
					
				}
				else
				{
					Global.echo( "Invalid value of the filename parameter." + help );
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
				Global.echo("Invalid value of the example parameter." +  help);
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