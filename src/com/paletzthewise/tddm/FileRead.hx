// Copyright 2025 Paletz
//
// This file is part of Elite Dangerous Transformative Data Dump Mirror (TDDM)
//
// TDDM is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
//
// TDDM is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License along with Foobar. If not, see <https://www.gnu.org/licenses/>.

package com.paletzthewise.tddm;
import php.Resource;
import php.Global;
import php.Exception;
import haxe.extern.EitherType;
import com.paletzthewise.tddm.PhpTools;

class FileRead
{
	private var handle : Resource;
	private var path : String;
	private var useGzip : Bool;

	public static function with( path : String, mode : String, useGzip : Bool, execute : FileRead -> Void ) : Void
	{
		PhpTools.with( 
			() -> new FileRead( path, mode, useGzip ),
			(fileRead) -> execute(fileRead),
			(fileRead) -> fileRead.destroy()
		);
	}
	
	public function new( path : String, mode : String, useGzip : Bool )
	{
		this.path = path;
		this.useGzip = useGzip;

		try 
		{
			handle = PhpTools.checkOutcome( open( mode ), 'FileRead: Failed to open file $path.' );
		}
		catch ( e : Exception )
		{
			throw new Exception( 'FileRead: Failed to open file $path due to ${e.getMessage()}' );
		}
	}
	
	public function destroy()
	{	
		if ( handle != null )
		{
			if ( ! Global.fclose( handle ) )
			{
				PhpTools.log( LogLevel.ERR, "FileRead: Failed to close the file." );
			}
			handle = null;
		}
	}
	
	// Get the handle to the temp file.
	//
	// Use with caution, generally don't close the handle.
	public function getHandle() : Resource
	{
		return handle;
	}

	public function getPath() : String
	{
		return path;
	}

	private function open( mode : String ) : Resource
	{
		if ( useGzip )
		{
			return PhpTools.checkOutcome( PhpToolsGlobal.gzopen( path, mode ), "Can't open gzipped file." );
		}
		else
		{
			return PhpTools.checkOutcome( Global.fopen( path, mode ), "Can't open file." );	
		}
	}
	

	public function read( length : Int ) : String
	{
		if ( useGzip )
		{
			return PhpTools.checkOutcome( PhpToolsGlobal.gzread( handle, length ), "Couldn't read the gzipped file." );
		}
		else
		{
			return PhpTools.checkOutcome( Global.fread( handle, length ), "Couldn't read the file." );
		}
	}
	
	public function readLine() : String
	{
		var retval : EitherType<String,Bool>;
		
		if ( useGzip )
		{
			retval = PhpToolsGlobal.gzgets( handle );
		}
		else
		{
			retval = Global.fgets( handle );
		}

		if ( retval is Bool )
		{
			return null;
		}
		else
		{
			return retval;
		}
	}
	
}