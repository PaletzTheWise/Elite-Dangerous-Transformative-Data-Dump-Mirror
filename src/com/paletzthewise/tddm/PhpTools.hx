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
import haxe.extern.EitherType;
import php.Resource;
import php.Exception;
import php.Global;
import php.SuperGlobal;
import php.Const;

@:phpGlobal
extern class PhpToolsGlobal
{
	static function curl_init( url : String ) : EitherType<Resource, Bool>;
	static function curl_setopt( handle : Resource, option : Int, value : Dynamic ) : Bool;
	static function curl_exec( handle : Resource ) : EitherType<String, Bool>;
	static function curl_getinfo( handle : Resource, ?option : Int ) : Dynamic;
	static function curl_close( handle : Resource ) : Void;
	static function readfile( filename : String, use_include_path : Bool = false, ?context : Resource ) : EitherType<Int, Bool>;
	static function stream_copy_to_stream( from : Resource, to : Resource, length : Int = null, offset : Int = 0 ) : EitherType<Int, Bool>;
	static function gzopen( filename : String, mode : String, use_include_path : Int = 0) : EitherType<Resource,Bool>;
	static function gzclose( stream : Resource ) : Bool;
	static function gzwrite( stream : Resource, data : String, length : Int = null ) : EitherType<Int,Bool>;
	static function gzread( stream : Resource, length : Int ) : EitherType<String,Bool>;
    static function gzgets( stream : Resource, length : Int = null ) : EitherType<String,Bool>;
}

@:phpGlobal
extern class PhpToolsConst
{
	static final CURLOPT_FILETIME : Int;
	static final CURLOPT_RETURNTRANSFER : Int;
	static final CURLOPT_HTTPHEADER : Int;
	static final CURLOPT_NOBODY : Int;
	static final CURLOPT_FILE : Int;
	static final CURLINFO_FILETIME : Int;
	static final LOG_EMERG : Int;
	static final LOG_ALERT : Int;
	static final LOG_CRIT : Int;
	static final LOG_ERR : Int;
	static final LOG_WARNING : Int;
	static final LOG_NOTICE : Int;
	static final LOG_INFO : Int;
	static final LOG_DEBUG : Int;	
}

enum LogLevel
{
	EMERG;
	ALERT;
	CRIT;	
	ERR;
	WARNING;
	NOTICE;
	INFO;
	DEBUG;
}

class PhpTools
{
	public static function checkOutcome<T>( outcome : EitherType<Bool, T>, exceptionText : String ) : T
	{
		if ( outcome is Bool && outcome == false )
		{
			throw new Exception( exceptionText );
		}
		else
		{
			return cast( outcome );
		}
	}
	
	public static function with<TResource, TRetval>( allocate : Void->TResource, execute : TResource->TRetval, dispose : TResource->Void ) : TRetval
	{
		var resource : TResource = null;
		try
		{
			resource = allocate();
			var retval = execute( resource );
			dispose( resource );
			return retval;
		}
		catch ( e )
		{
			if ( resource != null )
			{
				dispose( resource );
			}
			throw e;
		}
	}
	
	public static function log( level : LogLevel, message : String )
	{
		// PHP syslog() ends up in Event Viewer but error_log() ends up in php/logs/php_error_log. I prefer the file.
		
		var phpLevel = switch ( level )
		{
		case EMERG: PhpToolsConst.LOG_EMERG;
		case ALERT: PhpToolsConst.LOG_ALERT;
		case CRIT: PhpToolsConst.LOG_CRIT;
		case ERR: PhpToolsConst.LOG_ERR;
		case WARNING: PhpToolsConst.LOG_WARNING;
		case NOTICE: PhpToolsConst.LOG_NOTICE;
		case INFO: PhpToolsConst.LOG_INFO;
		case DEBUG: PhpToolsConst.LOG_DEBUG;
		default:
			message = "Invalid log level for the following log message: " + message;
			Const.E_ALL;
		}
		
		if ( Global.error_reporting() & phpLevel != 0)
		{
			Global.error_log( '[${level.getName()}] $message' );
		}
	}
	
	public static function getUrlToSelf() : String
	{
		var protocol;
		if ( Global.isset( SuperGlobal._SERVER['HTTPS'] ) && SuperGlobal._SERVER['HTTPS'] == 'on' )
		{
			protocol = "https://";
		}
		else
		{
			protocol = "http://";
		}
		
		return protocol + SuperGlobal._SERVER['HTTP_HOST'] + SuperGlobal._SERVER['REQUEST_URI'];
	}
	
	public static function getUrlToSelfFolder() : String
	{
		var pageUrl = getUrlToSelf();
		return pageUrl.substring( 0, pageUrl.lastIndexOf('/') + 1 );
	}
}