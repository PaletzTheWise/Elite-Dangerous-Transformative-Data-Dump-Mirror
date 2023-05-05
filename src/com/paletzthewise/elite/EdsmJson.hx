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

//These structures define edsm.net dump format.

typedef EdsmSystemRecord =
{
	id : Int,
	id64 : Int,
	name : String,	
	coords : EdsmCoordsRecord,
	allegiance : String,
	government : String,
	state : String,
	economy : String,
	security : String,
	population : Int,
	controllingFaction : EdsmFactionRecord,
	factions : Array<EdsmFactionPresenceRecord>,
	stations : Array<EdsmStationRecord>,
	bodies : Array<EdsmBodyRecord>,
	date : String,
}

typedef EdsmCoordsRecord =
{
	x : Float,
	y : Float,
	z : Float,
	
}

typedef EdsmFactionIdRecord =
{
	id : Int,
	name : String,
}

typedef EdsmFactionRecord =
{
	> EdsmFactionIdRecord,
	allegiance : String,
	government : String,
	isPlayer : Bool,
}

typedef EdsmFactionPresenceRecord =
{
	> EdsmFactionRecord,
	influence : Float,
	state : String,
	activeStates : Array<{state : String}>,
	recoveringStates : Array<{state : String}>,
	pendingStates : Array<{state : String}>,
	happiness : String,
	 lastUpdate : Int,
}

typedef EdsmStationRecord =
{
	id : Int,
	marketId : Int,
	type : String,
	name : String,
	body : EdsmBodyLocationRecord,
	distanceToArrival : Int,
	allegiance : String,
	government : String,
	economy : String,
	secondEconomy : String,
	haveMarket : Bool,
	haveShipyard : Bool,
	haveOutfitting : Bool,
	otherServices : Array<String>,
	controllingFaction : EdsmFactionIdRecord,
	updateTime : EdsmStationUpdateTimeRecord,
}

typedef EdsmStationUpdateTimeRecord =
{
	information : String,
	market : String,
	shipyard : String,
	outfitting : String,
}

typedef EdsmBodyLocationRecord =
{
	id : Int,
	name : String,
	latitude : Float,
	longitude : Float,
}

typedef EdsmBodyRecord =
{
	id : Int,
	id64 : Int,
	bodyId : Int,
	name : String,
	type : String,
	subType : String,
	parents : Array<EdsmParentRecord>,
	distanceToArrival : Int,
	isLandable : Bool, // planet/moon
	gravity : Float, // planet/moon
	isMainStar : Bool, // star
	isScoopable : Bool, // star
	age : Int, // star
	spectralClass : String, // star
	luminosity : String, // star
	absoluteMagnitude : Float, // star
	earthMasses : Float, // planet/moon
	solarMasses : Float, // star
	radius : Float, // planet/moon
	solarRadius : Float, // star
	surfaceTemperature : Int,
	surfacePressure : Float, // planet/moon
	volcanismType : String, // planet/moon
	atmosphereType : String, // planet/moon
	atmosphereComposition : EdsmCompositionRecord, // atmospheric planet/moon
	solidComposition : { Metal : Int, Rock : Int, Ice : Int }, // planet/moon
	terraformingState : String, // planet/moon
	orbitalPeriod : Float,
	semiMajorAxis : Float,
	orbitalEccentricity : Float,
	orbitalInclination : Float,
	argOfPeriapsis : Float,
	rotationalPeriod : Float,
	rotationalPeriodTidallyLocked : Bool,
	axialTilt : Float,
	belts : Array<EdsmBeltRecord>, // star
	materials : EdsmCompositionRecord, // landable planet/moon
	updateTime : String,
}

typedef EdsmBeltRecord =
{
	name : String,
	type : String,
	mass : Int,
	innerRadius : Int,
	outerRadius : Int,
}

typedef EdsmParentRecord =
{
	Star : Int,
	Planet : Int,
	Moon : Int,
	Null : Int,
}

typedef EdsmCompositionRecord = Dynamic;
// Element : Float