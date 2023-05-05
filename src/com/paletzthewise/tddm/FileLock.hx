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
import php.Resource;
import php.Global;
import php.Const;
import php.Exception;
import haxe.extern.EitherType;
import com.paletzthewise.tddm.PhpTools;

class FileLock
{
	private var handle : Resource;
	
	public static function with( path : String, execute : Void -> Void ) : Void
	{
		PhpTools.with( 
			() -> new FileLock( path ),
			(fileLock) -> execute(),
			(fileLock) -> fileLock.destroy()
		);
	}
	
	public function new( path : String, mode : String = "a" )
	{
		try 
		{
			handle = PhpTools.checkOutcome( Global.fopen( path, mode ), 'FileLock: Failed to open file for locking $path.' );
			
			if ( !Global.flock( handle, Const.LOCK_EX ) )
			{
				throw new Exception( 'FileLock: Failed to flock() $path for exclusive lock.' );
			}
		}
		catch ( e : Exception )
		{
			throw new Exception( 'FileLock: Failed to create a file lock for $path due to ${e.getMessage()}' );
		}
	}
	
	public function destroy()
	{	
		if ( handle != null )
		{
			if ( ! Global.fclose( handle ) )
			{
				PhpTools.log( LogLevel.ERR, "FileLock: Failed to close the file." );
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
}