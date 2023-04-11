package com.paletzthewise.tddm;
import php.Resource;
import php.Global;
import php.Exception;
import haxe.extern.EitherType;
import com.paletzthewise.tddm.PhpTools;

class TempFile
{
	private var handle : Resource;
	private var path : String;
	private var useGzip : Bool;
	
	public static function with( directory : String, prefix : String, mode : String, useGzip : Bool, execute : TempFile -> Void ) : Void
	{
		PhpTools.with(
			() -> new TempFile( directory, prefix, mode, useGzip ),
			execute,
			(tempFile) -> tempFile.destroy()
		);
	}
	
	public function new( directory : String, prefix : String, mode : String, useGzip : Bool )
	{
		this.useGzip = useGzip;
		try 
		{
			path = PhpTools.checkOutcome( Global.tempnam( directory, prefix ), 'Failed to create temp file starting with $prefix in $directory.' );
		}
		catch ( e : Exception )
		{
			throw new Exception( 'Failed to create temp file starting with $prefix in $directory due to ${e.getMessage()}' );
		}
		handle = open( mode );
	}
	
	public function destroy()
	{
		if ( handle != null )
		{
			close();
			handle = null;
		}
		
		if ( path != null )
		{
			if ( ! Global.unlink( path ) )
			{
				PhpTools.log( LogLevel.ERR, 'TempFile: Failed to unlink temp file $path' );
			}
			
			path = null;
		}
	}
	
	public function write( bytes : String ) : Int
	{
		if ( handle == null )
		{
			throw new Exception( "Can't write, the temporary file is not open." );
		}
		
		if ( useGzip )
		{
			return PhpTools.checkOutcome( PhpToolsGlobal.gzwrite( handle, bytes ), "Failed to compress and write bytes." );
		}
		else
		{
			return PhpTools.checkOutcome( Global.fwrite( handle, bytes ), "Failed to write bytes." );
		}
	}
	
	public function writeStream( stream : Resource, length : Int = null, offset : Int = 0 ) : Int
	{
		if ( handle == null )
		{
			throw new Exception( "Can't write, the temporary file is not open." );
		}
		
		if ( stream == null )
		{
			throw new Exception( "Can't write null stream.");
		}
		
		return PhpTools.checkOutcome( PhpToolsGlobal.stream_copy_to_stream( stream, handle, length, offset ), "Failed to write stream." );		
	}
	
	public function persist( permanentNameOrPath : String )
	{
		if ( handle == null )
		{
			throw new Exception( "Can't persist, the temporary file is not open." );
		}
		
		close();
		if ( !Global.rename( path, permanentNameOrPath ) )
		{
			throw new Exception( "Can't persist, renaming failed." );
		}
		
		handle = null;
		path = null;
	}
	
	public function reopen( mode : String, useGzip : Bool )
	{
		if ( handle == null )
		{
			throw new Exception( "Can't reopen, the temporary file is not open." );
		}
		
		close();
		
		this.useGzip = useGzip;
		
		handle = open( mode );
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
	
	// Get the handle to the temp file.
	//
	// Use with caution, generally don't close the handle.
	public function getHandle() : Resource
	{
		return handle;
	}
	
	private function open( mode : String ) : Resource
	{
		if ( useGzip )
		{
			return PhpTools.checkOutcome( PhpToolsGlobal.gzopen( path, mode ), "Can't create temporary gzipped file." );
		}
		else
		{
			return PhpTools.checkOutcome( Global.fopen( path, mode ), "Can't create temporary file." );	
		}
	}
	
	private function close()
	{
		if ( useGzip )
		{
			if ( ! PhpToolsGlobal.gzclose( handle ) )
			{
				PhpTools.log( LogLevel.ERR, "TempFile: Failed to close temp gzipped file." );
			}
		}
		else
		{
			if ( ! Global.fclose( handle ) )
			{
				PhpTools.log( LogLevel.ERR, "TempFile: Failed to close temp file." );
			}
		}
		
		handle = null;
	}
}