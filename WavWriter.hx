/*
** WavWriter.hx
**
** Copyright (c) 2011-2014 Peter McQuillan
**
** All Rights Reserved.
**                       
** Distributed under the BSD Software License (see license.txt)  
**
*/

class WavWriter
{
	static function write_uint32(f : haxe.io.Output, v : haxe.Int32, bigendian : Int) : Void
	{
		f.writeInt32(v);
	}

	static function write_uint16(f : haxe.io.Output, v : Int, bigendian : Int) : Void
	{
		f.writeInt16(v);
	}

	public static function wavwriter_writeheaders(f : haxe.io.Output, datasize : Int, numchannels : Int, samplerate : Int, bitspersample : Int) : Void
	{
		var buffAsBytes = haxe.io.Bytes.alloc(4);

		/* write RIFF header */
		buffAsBytes.set(0,82);
		buffAsBytes.set(1,73);
		buffAsBytes.set(2,70);
		buffAsBytes.set(3,70); 	// "RIFF" ascii values

		f.writeBytes(buffAsBytes, 0, 4 );

		write_uint32(f, (36 + datasize), 0);
		buffAsBytes.set(0,87);
		buffAsBytes.set(1,65);
		buffAsBytes.set(2,86);
		buffAsBytes.set(3,69);  // "WAVE" ascii values

		f.writeBytes(buffAsBytes, 0, 4 );

		/* write fmt header */
		buffAsBytes.set(0,102);
		buffAsBytes.set(1,109);
		buffAsBytes.set(2,116);
		buffAsBytes.set(3,32);  // "fmt " ascii values

		f.writeBytes(buffAsBytes, 0, 4 );

		write_uint32(f, 16, 0);
		write_uint16(f, 1, 0); // PCM data
		write_uint16(f, numchannels, 0);
		write_uint32(f, samplerate, 0);
		write_uint32(f, (samplerate * numchannels * Std.int(bitspersample / 8)), 0); // byterate
		write_uint16(f, (numchannels * Std.int(bitspersample / 8)), 0);
		write_uint16(f, bitspersample, 0);

		/* write data header */
		buffAsBytes.set(0,100);
		buffAsBytes.set(1,97);
		buffAsBytes.set(2,116);
		buffAsBytes.set(3,97);  // "data" ascii values

		f.writeBytes(buffAsBytes, 0, 4 );
		write_uint32(f, datasize, 0);
	}
}

