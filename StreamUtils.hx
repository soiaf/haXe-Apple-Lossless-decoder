/*
** StreamUtils.hx
**
** Copyright (c) 2011 Peter McQuillan
**
** All Rights Reserved.
**                       
** Distributed under the BSD Software License (see license.txt)  
**
*/

class StreamUtils
{
#if flash10
	public static function stream_read(mystream : MyStream, size : Int, buf : flash.Vector < Int >, startPos : Int) : Void
#else
	public static function stream_read(mystream : MyStream, size : Int, buf : Array < Int >, startPos : Int) : Void
#end
	{
		var bytes_read : Int = 0;
		var bytebuf = haxe.io.Bytes.alloc(size);
		
		try
		{
			bytes_read = mystream.stream.readBytes(bytebuf, 0, size);
		}
		catch(err: Dynamic)
		{
			trace("stream_read: exception thrown: " + err);
		}
		mystream.currentPos = mystream.currentPos + bytes_read;
		
		for (i in 0 ... bytes_read)
		{
			buf[startPos + i] = bytebuf.get(i);
		}
	}

	public static function stream_read_uint32(mystream : MyStream) : haxe.Int32
	{
		var v : haxe.Int32 = haxe.Int32.ofInt(0);
		var tmp : haxe.Int32 = haxe.Int32.ofInt(0);
		var bytebuf = haxe.io.Bytes.alloc(4);
		var bytes_read : Int = 0;

		try
		{
			bytes_read = mystream.stream.readBytes(bytebuf, 0, 4);
			mystream.currentPos = mystream.currentPos + 4;
			tmp = haxe.Int32.ofInt(bytebuf.get(0));

			v = haxe.Int32.shl(tmp,24);
			tmp = haxe.Int32.ofInt(bytebuf.get(1));

			v = haxe.Int32.or(v, haxe.Int32.shl(tmp,16));
			tmp = haxe.Int32.ofInt(bytebuf.get(2));

			v = haxe.Int32.or(v, haxe.Int32.shl(tmp,8));
			tmp = haxe.Int32.ofInt(bytebuf.get(3));

			v = haxe.Int32.or(v, tmp);

		}
		catch(err: Dynamic)
		{
			trace("stream_read_uint32: exception thrown: " + err);
		}
		
		return v;
	}

	public static function stream_read_int16(mystream : MyStream) : Int
	{
		var v : Int;
		v = mystream.stream.readInt16();
		mystream.currentPos = mystream.currentPos + 2;
		return v;
	}
	public static function stream_read_uint16(mystream : MyStream) : Int
	{
		var v : Int = 0;
		var tmp : Int = 0;
		var bytebuf = haxe.io.Bytes.alloc(2);
		var bytes_read : Int = 0;

		try
		{
			bytes_read = mystream.stream.readBytes(bytebuf,0,2);
			mystream.currentPos = mystream.currentPos + 2;
			tmp = (bytebuf.get(0) << 8);
			v = tmp | bytebuf.get(1);
		}
		catch(err: Dynamic)
		{
		}

		return v;
	}

	public static function stream_read_uint8(mystream : MyStream) : Int
	{
		var v : Int;
		v = mystream.stream.readByte();
		mystream.currentPos = mystream.currentPos + 1;
		return v;
	}

	public static function stream_skip(mystream : MyStream, skip : Int) : Void
	{
		var bytebuf = haxe.io.Bytes.alloc(8192);
		var toskip : Int = skip;
		var toget : Int = 0;
		var bytes_read : Int = 0;

		if(toskip < 0)
		{
			trace("stream_skip: request to seek backwards in stream - not supported, sorry");
			return;
		}

		while(toskip > 0)
		{
			if(toskip > 8192)
			{
				toget = 8192;
				toskip = toskip - 8192;
			}
			else
			{
				toget = toskip;
				toskip = 0;
			}

			try
			{
				bytes_read = mystream.stream.readBytes(bytebuf, 0, toget);
				mystream.currentPos = mystream.currentPos + bytes_read;
			}
			catch(err: Dynamic)
			{
			}
		}
	}

	public static function stream_eof(mystream : MyStream) : Int
	{
		// TODO

		return 0;
	}

	public static function stream_tell(mystream : MyStream) : Int
	{
		return (mystream.currentPos);
	}
	public static function stream_setpos(mystream : MyStream, pos : Int) : Int
	{		
		return -1;
	}

}

