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

//These structures define eddb.io dump format.

typedef EddbFactionStateRecord =
{
	name : String,
	id : Int,
}

typedef EddbFactionPresenceRecord =
{
	minor_faction_id : Int,
	active_states : Array<EddbFactionStateRecord>,
	pending_states : Array<EddbFactionStateRecord>,
	recovering_states : Array<EddbFactionStateRecord>,
	influence : Float,
	happiness_id : Int,
}

typedef EddbStationRecord =
{
	id : Int,
	name : String,
	system_id : Int,
	distance_to_star : Int,
	type : String,
	has_docking : Bool,
	controlling_minor_faction_id : Int,
}

typedef EddbSystemRecord = 
{
	id : Int,
	name : String,
	x : Float,
	y : Float,
	z : Float,
	population : Int,
	minor_faction_presences : Array<EddbFactionPresenceRecord>,
	allegiance : String,
	primary_economy : String,
	primary_economy_id : Int,
}

typedef EddbFactionRecord =
{
	id : Int,
	name : String,
	government_name : String,
	allegiance : String,
	allegiance_id : Int,
	home_system_id : Int,
	is_player_faction : Bool,
	updated_at : Int,
	government_id : Int,
	government : String,
}