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