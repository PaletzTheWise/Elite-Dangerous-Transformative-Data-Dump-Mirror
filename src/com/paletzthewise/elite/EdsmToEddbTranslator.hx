// Copyright 2023 Paletz
//
// This file is part of Elite Dangerous Transformative Data Dump Mirror (TDDM)
//
// TDDM is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
//
// TDDM is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License along with Foobar. If not, see <https://www.gnu.org/licenses/>.
	
package com.paletzthewise.elite;
import com.paletzthewise.elite.EdsmJson;
import com.paletzthewise.elite.EddbJson;
import haxe.Exception;
import haxe.Json;

class EdsmToEddbTranslator
{

	var definedFactionIds = new Map<Int,Int>(); // value is unused
	
	public function new()
	{
	}
	
	public function translateFactionPresence( edsmSystem : EdsmSystemRecord, edsmFactionPresence : EdsmFactionPresenceRecord ) : Dynamic
	{
		var eddbFactionPresence : EddbFactionPresenceRecord = (
			{
				minor_faction_id : edsmFactionPresence.id,
				active_states : edsmFactionPresence.activeStates.map( edsmFactionStateToEddb ),
				pending_states : edsmFactionPresence.pendingStates.map( edsmFactionStateToEddb ),
				recovering_states : edsmFactionPresence.recoveringStates.map( edsmFactionStateToEddb ),
				influence : edsmFactionPresence.influence,
				happiness_id : -1, // ???
			}
		);
			
		return eddbFactionPresence;
	}
	
	
	public function translateFaction( edsmFactionPresence : EdsmFactionPresenceRecord ) : Dynamic
	{
		var eddbFaction : EddbFactionRecord = (
			{
				id : edsmFactionPresence.id,
				name : edsmFactionPresence.name,
				government_name : edsmFactionPresence.government,
				allegiance : edsmFactionPresence.allegiance,
				allegiance_id : -1, // ???
				home_system_id : -1, // ???
				is_player_faction : edsmFactionPresence.isPlayer,
				updated_at : edsmFactionPresence.lastUpdate,
				government_id : -1, // ???
				government : edsmFactionPresence.government,
			}
		);
		
		return eddbFaction;
	}
	
	public function translateStation( edsmSystem : EdsmSystemRecord, edsmStation : EdsmStationRecord ) : Dynamic
	{
		var eddbStation : EddbStationRecord = (
			{
				id : edsmStation.id,
				name : edsmStation.name,
				system_id : edsmSystem.id,
				distance_to_star : edsmStation.distanceToArrival,
				type : StringTools.replace( edsmStation.type, " ", "" ),
				has_docking : true, // the only stations that have false in EDDB are "UnknownDockable" and about a hundred OddyseySettlements
				controlling_minor_faction_id : ( edsmStation.controllingFaction != null ? edsmStation.controllingFaction.id : null ),
			}
		);
		
		return eddbStation;
	}
	
	public function translateSystem( edsmSystem : EdsmSystemRecord, translatedFactionPresenses : Array<Dynamic> ) : Dynamic
	{
		var eddbSystem : EddbSystemRecord = (
			{
				id : edsmSystem.id,
				name : edsmSystem.name,
				x : edsmSystem.coords.x,
				y : edsmSystem.coords.y,
				z : edsmSystem.coords.z,
				population : edsmSystem.population,
				allegiance : edsmSystem.allegiance,
				primary_economy : edsmSystem.economy,
				primary_economy_id : -1, // ???
				minor_faction_presences : cast( translatedFactionPresenses ),
			}
		);
		
		return eddbSystem;
	}
	
	/** Translate EDSM system record into EDDB records
	 * 
	 * If a faction was seen before, then it won't be included again in the faction records.
	**/
	public function translate( edsmSystem : EdsmSystemRecord ) : { system : Dynamic, stations : Array<Dynamic>, factions : Array<Dynamic> }
	{
		if ( edsmSystem.factions == null )
		{
			throw new Exception( "Can't translate due to missing faction information." );
		}
		
		var translatedFactionRecords = new Array<Dynamic>();
		var translatedFactionPresences = new Array<Dynamic>();
		for ( edsmFactionPresence in edsmSystem.factions )
		{
			translatedFactionPresences.push( translateFactionPresence( edsmSystem, edsmFactionPresence ) );
			
			if ( !definedFactionIds.exists( edsmFactionPresence.id ) )
			{
				definedFactionIds.set( edsmFactionPresence.id, null );
				
				translatedFactionRecords.push( translateFaction( edsmFactionPresence ) );
			}
		}
		
		var translatedStations = new Array<Dynamic>();
		for ( edsmStation in edsmSystem.stations )
		{
			translatedStations.push( translateStation( edsmSystem, edsmStation ) );
		}
		
		return (
			{
				system : translateSystem( edsmSystem, translatedFactionPresences ),
				stations : translatedStations,
				factions : translatedFactionRecords,
			}
		);
	}
	
	public function transform( 
		readEdsmLine : Void->String,
		writeToSystems : String->Void,
		writeToStations : String->Void,
		writeToFactions : String->Void,
		reportIssue : String->Void,
	)
	{
		writeToSystems("[");
		writeToStations("[");
		writeToFactions("[");

		var firstSystem = true;
		var firstFaction = true;
		var firstStation = true;
		
		while ( true )
		{
			// Each line is a record in the array of systems.
			// Parse one system at a time to keep ram usage low.
			
			var line = readEdsmLine();
			if ( line == null )
			{
				break;
			}
			
			if ( line.length < 3 ) // [ or ]
			{
				continue;
			}
			
			// get rid of the comma at the end
			line = line.substr( 0, line.lastIndexOf('}') + 1 );
			
			var edsmSystem : EdsmSystemRecord = (
				try 
				{
					cast( Json.parse( line ) );
				}
				catch ( e : Exception )
				{
					throw new Exception( 'Failed to parse system record that starts with "${line.substr(0,20)}": ${e.message}' ); 
				}
			);
			
			var translatedRecords;
			try
			{
				translatedRecords = translate( edsmSystem );
			}
			catch ( e : Exception )
			{
				reportIssue( 'Skipping "${edsmSystem.name}": ${e.message}' );
				continue;
			}
			
			for ( translatedFaction in translatedRecords.factions )
			{
				writeToFactions( ( firstFaction ? "\n" : ",\n" ) + Json.stringify( translatedFaction ) );
				firstFaction = false;
			}
			
			for ( translatedStation in translatedRecords.stations )
			{
				writeToStations( ( firstStation ? "\n" : ",\n" ) + Json.stringify( translatedStation ) );
				firstStation = false;
			}
			
			writeToSystems( ( firstSystem ? "\n" : ",\n" ) + Json.stringify( translatedRecords.system ) );
			firstSystem = false;
		}
		
		writeToSystems("\n]");
		writeToFactions("\n]");
		writeToStations("\n]");
	}
	
	private static function edsmFactionStateToEddb( edsmState : {state : String} ) : EddbFactionStateRecord
	{
		return (
			{
				name : edsmState.state,
				id : -1, // ???
			}
		);
	}
}