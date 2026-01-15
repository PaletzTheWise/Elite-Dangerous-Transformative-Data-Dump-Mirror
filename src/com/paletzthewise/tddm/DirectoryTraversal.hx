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

import com.paletzthewise.tddm.PhpTools;
import php.Exception;
import php.Global;
import php.Const;

class DirectoryTraversal
{
	private var handle : php.Resource;
	private var path : String;
	
	public static function with( path : String, execute : DirectoryTraversal -> Void ) : Void
	{
		PhpTools.with(
			() -> new DirectoryTraversal( path ),
			execute,
			(directoryTraversal) -> directoryTraversal.destroy()
		);
	}
	
	public function new( path : String )
	{
		this.path = path;
		try 
		{
			handle = PhpTools.checkOutcome( Global.opendir(path), 'Failed to open directory $path.' );
		}
		catch ( e : Exception )
		{
			throw new Exception( 'Failed to open directory $path due to ${e.getMessage()}' );
		}
	}
	
	public function destroy()
	{
		if ( handle != null )
		{
			Global.closedir(handle);
			handle = null;
		}
	}

	public function next() : String
	{
		if (handle == null)
		{
			throw new Exception( 'Directory traversal is not open.' );
		}

		
		var retval = Global.readdir(handle);
		
		if ( retval is Bool )
		{
			return null;
		}

		return retval;
	}

	public function for_each_filename(execute : String -> Void) : Void
	{
		while(true)
		{
			var filename = next();

			if ( [".",".."].contains(filename) )
			{
				continue;
			}

			if (filename != null)
			{
				execute(filename);
			}
			else
			{
				break;
			}
		}
	}

	public function for_each_path(execute : String -> Void) : Void
	{
		for_each_filename(
			function (filename : String)
			{
				execute( path + Const.DIRECTORY_SEPARATOR + filename );
			}
		);
	}
}
