package com.paletzthewise.elite;
import com.paletzthewise.elite.EdsmJson;
import com.paletzthewise.elite.EddbJson;
import haxe.Exception;
import haxe.Json;

class EdsmToEddbSystemTranslator
{

	var definedFactionIds = new Map<Int,Int>(); // value is unused
	
	public function new()
	{
	}
	
	/** Translate EDSM system record into EDDB records
	 * 
	 * If a faction was seen before, then it won't be included again in the faction records.
	**/
	public function translate( edsmSystem : EdsmSystemRecord ) : { system : EddbSystemRecord, stations : Array<EddbStationRecord>, factions : Array<EddbFactionRecord> }
	{
		if ( edsmSystem.factions == null )
		{
			throw new Exception( "Can't translate due to missing faction information." );
		}
		
		var newEddbFactionRecords = new Array<EddbFactionRecord>();
		var eddbFactionPresences = new Array<EddbFactionPresenceRecord>();
		for ( edsmFactionPresence in edsmSystem.factions )
		{
			eddbFactionPresences.push(
				{
					minor_faction_id : edsmFactionPresence.id,
					active_states : edsmFactionPresence.activeStates.map( edsmFactionStateToEddb ),
					pending_states : edsmFactionPresence.pendingStates.map( edsmFactionStateToEddb ),
					recovering_states : edsmFactionPresence.recoveringStates.map( edsmFactionStateToEddb ),
					influence : edsmFactionPresence.influence,
					happiness_id : -1, // ???
				}
			);
			
			if ( !definedFactionIds.exists( edsmFactionPresence.id ) )
			{
				definedFactionIds.set( edsmFactionPresence.id, null );
				newEddbFactionRecords.push( 
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
			}
		}
		
		var eddbStations = new Array<EddbStationRecord>();
		for ( edsmStation in edsmSystem.stations )
		{
			eddbStations.push( 
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
		}
		
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
				minor_faction_presences : eddbFactionPresences,
			}
		);
		
		return (
			{
				system : eddbSystem,
				stations : eddbStations,
				factions : newEddbFactionRecords,
			}
		);
	}
	
	public static function transform( readEdsmLine : Void->String, writeToEddbSystems : String->Void,  writeToEddbStations : String->Void, writeToEddbFactions : String->Void, reportIssue : String->Void )
	{
		writeToEddbSystems("[");
		writeToEddbStations("[");
		writeToEddbFactions("[");

		var firstSystem = true;
		var firstFaction = true;
		var firstStation = true;
		
		var translator = new EdsmToEddbSystemTranslator();
		
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
			
			var eddbRecords;
			try
			{
				eddbRecords = translator.translate( edsmSystem );
			}
			catch ( e : Exception )
			{
				reportIssue( 'Skipping "${edsmSystem.name}": ${e.message}' );
				continue;
			}
			
			for ( eddbFaction in eddbRecords.factions )
			{
				writeToEddbFactions( ( firstFaction ? "\n" : ",\n" ) + Json.stringify( eddbFaction ) );
				firstFaction = false;
			}
			
			for ( eddbStation in eddbRecords.stations )
			{
				writeToEddbStations( ( firstStation ? "\n" : ",\n" ) + Json.stringify( eddbStation ) );
				firstStation = false;
			}
			
			writeToEddbSystems( ( firstSystem ? "\n" : ",\n" ) + Json.stringify( eddbRecords.system ) );
			firstSystem = false;
		}
		
		writeToEddbSystems("\n]");
		writeToEddbFactions("\n]");
		writeToEddbStations("\n]");
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