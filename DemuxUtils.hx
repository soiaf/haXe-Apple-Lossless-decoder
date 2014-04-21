/*
** DemuxUtils.hx
**
** Copyright (c) 2011-2014 Peter McQuillan
**
** All Rights Reserved.
**                       
** Distributed under the BSD Software License (see license.txt)  
**
*/

class DemuxUtils
{
	public static function MakeFourCC(ch0 : Int, ch1 : Int, ch2 : Int, ch3 : Int) : Int
	{
		return ( ((ch0) << 24)| ((ch1) << 16)| ((ch2) << 8) | ((ch3)) );
	}

	public static function MakeFourCC32(ch0 : Int, ch1 : Int, ch2 : Int, ch3 : Int) : haxe.Int32
	{
		var retval : haxe.Int32 = 0;
		var tmp : haxe.Int32 = ch0;

		retval = tmp << 24;

		tmp = ch1;

		retval = (retval | (tmp << 16));
		tmp = ch2;

		retval = (retval | (tmp << 8));
		tmp = ch3;

		retval = (retval | tmp);

		return (retval);
	}


	public static function qtmovie_read(file : haxe.io.Input, qtmovie : QTMovieT, demux_res : DemuxResT) : Int
	{
		var found_moov : Int = 0;
		var found_mdat : Int = 0;

		/* construct the stream */
		qtmovie.qtstream.stream = file;

		qtmovie.res = demux_res;

		// reset demux_res	TODO

		/* read the chunks */
		while (true)
		{
			var chunk_len : Int;
			var chunk_id : haxe.Int32;

			try
			{
				chunk_len = StreamUtils.stream_read_uint32(qtmovie.qtstream);
			}
			catch(err: Dynamic)
			{
				trace("(top) error reading chunk_len - possibly number too large");
				chunk_len = 1;
			}
			
			if (StreamUtils.stream_eof(qtmovie.qtstream) != 0)
			{
				return 0;
			}

			if (chunk_len == 1)
			{
				trace("need 64bit support");
				return 0;
			}
			chunk_id = StreamUtils.stream_read_uint32(qtmovie.qtstream);

			if(haxe.Int32.ucompare(chunk_id, MakeFourCC32(102,116,121,112) ) == 0 )	// fourcc equals ftyp
			{
				read_chunk_ftyp(qtmovie, chunk_len);
			}
			else if(haxe.Int32.ucompare(chunk_id, MakeFourCC32(109,111,111,118)) == 0 )	// fourcc equals moov
			{
				if (read_chunk_moov(qtmovie, chunk_len) == 0)
					return 0; // failed to read moov, can't do anything
				if (found_mdat != 0)
				{
					return set_saved_mdat(qtmovie);
				}
				found_moov = 1;
			}
				/* if we hit mdat before we've found moov, record the position
				 * and move on. We can then come back to mdat later.
				 * This presumes the stream supports seeking backwards.
				 */
			else if(haxe.Int32.ucompare(chunk_id, MakeFourCC32(109,100,97,116)) == 0 )	// fourcc equals mdat
			{
				var not_found_moov : Int = 0;
				if(found_moov==0)
					not_found_moov = 1;
				read_chunk_mdat(qtmovie, chunk_len, not_found_moov);
				if (found_moov != 0)
				{
					return 1;
				}
				found_mdat = 1;
			}
				/*  these following atoms can be skipped !!!! */
			else if(haxe.Int32.ucompare(chunk_id, MakeFourCC32(102,114,101,101)) == 0 )	// fourcc equals free
			{
				StreamUtils.stream_skip(qtmovie.qtstream, chunk_len - 8); // FIXME not 8
			}
			else
			{
				trace("(top) unknown chunk id: " + chunk_id);
				return 0;
			}
		}
		return 0;
	}


	/* chunk handlers */
	static function read_chunk_ftyp(qtmovie : QTMovieT, chunk_len : Int) : Void
	{
		var type : haxe.Int32 = 0;
		var minor_ver : haxe.Int32 = 0;
		var size_remaining : Int = chunk_len - 8; // FIXME: can't hardcode 8, size may be 64bit

		type = StreamUtils.stream_read_uint32(qtmovie.qtstream);
		size_remaining-=4;

		if(haxe.Int32.ucompare(type, MakeFourCC32(77,52,65,32) ) != 0 )		// "M4A " ascii values
		{
			trace("not M4A file");
			return;
		}
		minor_ver = StreamUtils.stream_read_uint32(qtmovie.qtstream);
		size_remaining-=4;

		/* compatible brands */
		while (size_remaining != 0)
		{
			/* unused */
			/*fourcc_t cbrand =*/
			StreamUtils.stream_read_uint32(qtmovie.qtstream);
			size_remaining-=4;
		}
	}

	static function read_chunk_tkhd(qtmovie : QTMovieT, chunk_len : Int) : Void
	{
		/* don't need anything from here atm, skip */
		var size_remaining : Int = chunk_len - 8; // FIXME WRONG

		StreamUtils.stream_skip(qtmovie.qtstream, size_remaining);
	}

	static function read_chunk_mdhd(qtmovie : QTMovieT, chunk_len : Int) : Void
	{
		/* don't need anything from here atm, skip */
		var size_remaining : Int = chunk_len - 8; // FIXME WRONG

		StreamUtils.stream_skip(qtmovie.qtstream, size_remaining);
	}

	static function read_chunk_edts(qtmovie : QTMovieT, chunk_len : Int) : Void
	{
		/* don't need anything from here atm, skip */
		var size_remaining : Int = chunk_len - 8; // FIXME WRONG

		StreamUtils.stream_skip(qtmovie.qtstream, size_remaining);
	}

	static function read_chunk_elst(qtmovie : QTMovieT, chunk_len : Int) : Void
	{
		/* don't need anything from here atm, skip */
		var size_remaining : Int = chunk_len - 8; // FIXME WRONG

		StreamUtils.stream_skip(qtmovie.qtstream, size_remaining);
	}

	/* media handler inside mdia */
	static function read_chunk_hdlr(qtmovie : QTMovieT, chunk_len : Int) : Void
	{
		var comptype : haxe.Int32 = 0;
		var compsubtype : haxe.Int32 = 0;
		var size_remaining : Int = chunk_len - 8; // FIXME WRONG

		var strlen : Int;
		var str : Array < Int > = new Array();

		/* version */
		StreamUtils.stream_read_uint8(qtmovie.qtstream);
		size_remaining -= 1;
		/* flags */
		StreamUtils.stream_read_uint8(qtmovie.qtstream);
		StreamUtils.stream_read_uint8(qtmovie.qtstream);
		StreamUtils.stream_read_uint8(qtmovie.qtstream);
		size_remaining -= 3;

		/* component type */
		comptype = StreamUtils.stream_read_uint32(qtmovie.qtstream);
		compsubtype = StreamUtils.stream_read_uint32(qtmovie.qtstream);
		size_remaining -= 8;

		/* component manufacturer */
		StreamUtils.stream_read_uint32(qtmovie.qtstream);
		size_remaining -= 4;

		/* flags */
		StreamUtils.stream_read_uint32(qtmovie.qtstream);
		StreamUtils.stream_read_uint32(qtmovie.qtstream);
		size_remaining -= 8;

		/* name */
		strlen = StreamUtils.stream_read_uint8(qtmovie.qtstream);

		/* 
		** rewrote this to handle case where we actually read more than required 
		** so here we work out how much we need to read first
		*/

		size_remaining -= 1;

		StreamUtils.stream_skip(qtmovie.qtstream, size_remaining);
	}

	static function read_chunk_stsd(qtmovie : QTMovieT, chunk_len : Int) : Int
	{
		var i : Int;
		var numentries : Int = 0;
		var size_remaining : Int = chunk_len - 8; // FIXME WRONG

		/* version */
		StreamUtils.stream_read_uint8(qtmovie.qtstream);
		size_remaining -= 1;
		/* flags */
		StreamUtils.stream_read_uint8(qtmovie.qtstream);
		StreamUtils.stream_read_uint8(qtmovie.qtstream);
		StreamUtils.stream_read_uint8(qtmovie.qtstream);
		size_remaining -= 3;

		try
		{
			numentries = StreamUtils.stream_read_uint32(qtmovie.qtstream);
		}
		catch(err: Dynamic)
		{
			trace("(read_chunk_stsd) error reading numentries - possibly number too large");
			numentries = 0;
		}		
		

		size_remaining -= 4;

		if (numentries != 1)
		{
			trace("only expecting one entry in sample description atom!");
			return 0;
		}

		for (i in 0 ... numentries)
		{
			var entry_size : Int;
			var version : Int;

			var entry_remaining : Int;

			entry_size = StreamUtils.stream_read_uint32(qtmovie.qtstream);
			qtmovie.res.format = StreamUtils.stream_read_uint32(qtmovie.qtstream);
			entry_remaining = entry_size;
			entry_remaining -= 8;

			/* sound info: */

			StreamUtils.stream_skip(qtmovie.qtstream, 6); // reserved
			entry_remaining -= 6;

			version = StreamUtils.stream_read_uint16(qtmovie.qtstream);

			if (version != 1)
				trace("unknown version??");
			entry_remaining -= 2;

			/* revision level */
			StreamUtils.stream_read_uint16(qtmovie.qtstream);
			/* vendor */
			StreamUtils.stream_read_uint32(qtmovie.qtstream);
			entry_remaining -= 6;

			/* EH?? spec doesn't say theres an extra 16 bits here.. but there is! */
			StreamUtils.stream_read_uint16(qtmovie.qtstream);
			entry_remaining -= 2;

			qtmovie.res.num_channels = StreamUtils.stream_read_uint16(qtmovie.qtstream);

			qtmovie.res.sample_size = StreamUtils.stream_read_uint16(qtmovie.qtstream);
			entry_remaining -= 4;

			/* compression id */
			StreamUtils.stream_read_uint16(qtmovie.qtstream);
			/* packet size */
			StreamUtils.stream_read_uint16(qtmovie.qtstream);
			entry_remaining -= 4;

			/* sample rate - 32bit fixed point = 16bit?? */
			qtmovie.res.sample_rate = StreamUtils.stream_read_uint16(qtmovie.qtstream);
			entry_remaining -= 2;

			/* skip 2 */
			StreamUtils.stream_skip(qtmovie.qtstream, 2);
			entry_remaining -= 2;

			/* remaining is codec data */

			/* 12 = audio format atom, 8 = padding */
			qtmovie.res.codecdata_len = entry_remaining + 12 + 8;

			for (count in 0 ... qtmovie.res.codecdata_len)
			{
				qtmovie.res.codecdata[count] = 0;
			}

			/* audio format atom */
			qtmovie.res.codecdata[0] = 0x0c000000;
			qtmovie.res.codecdata[1] = MakeFourCC(97,109,114,102);		// "amrf" ascii values
			qtmovie.res.codecdata[2] = MakeFourCC(99,97,108,97);		// "cala" ascii values

			StreamUtils.stream_read(qtmovie.qtstream, entry_remaining, qtmovie.res.codecdata, 12);	// codecdata buffer should be +12
			entry_remaining -= entry_remaining;

			if (entry_remaining != 0)	// was comparing to null
				StreamUtils.stream_skip(qtmovie.qtstream, entry_remaining);

			qtmovie.res.format_read = 1;
			if(haxe.Int32.ucompare(qtmovie.res.format, MakeFourCC32(97,108,97,99) ) != 0 )		// "alac" ascii values
			{
				return 0;
			}
		}

		return 1;
	}

	static function read_chunk_stts(qtmovie : QTMovieT, chunk_len : Int) : Void
	{
		var i : Int;
		var numentries : Int = 0;
		var size_remaining : Int = chunk_len - 8; // FIXME WRONG

		/* version */
		StreamUtils.stream_read_uint8(qtmovie.qtstream);
		size_remaining -= 1;
		/* flags */
		StreamUtils.stream_read_uint8(qtmovie.qtstream);
		StreamUtils.stream_read_uint8(qtmovie.qtstream);
		StreamUtils.stream_read_uint8(qtmovie.qtstream);
		size_remaining -= 3;

		try
		{
			numentries = StreamUtils.stream_read_uint32(qtmovie.qtstream);
		}
		catch(err: Dynamic)
		{
			trace("(read_chunk_stts) error reading numentries - possibly number too large");
			numentries = 0;
		}

		size_remaining -= 4;

		qtmovie.res.num_time_to_samples = numentries;

		for (i in 0 ... numentries)
		{
			qtmovie.res.time_to_sample[i].sample_count = StreamUtils.stream_read_uint32(qtmovie.qtstream);
			qtmovie.res.time_to_sample[i].sample_duration = StreamUtils.stream_read_uint32(qtmovie.qtstream);
			size_remaining -= 8;
		}

		if (size_remaining != 0)
		{
			trace("(read_chunk_stts) size remaining?");
			StreamUtils.stream_skip(qtmovie.qtstream, size_remaining);
		}
	}

	static function read_chunk_stsz(qtmovie : QTMovieT, chunk_len : Int) : Void
	{
		var i : Int;
		var numentries : Int = 0;
		var uniform_size : Int = 0;
		var size_remaining : Int = chunk_len - 8; // FIXME WRONG

		/* version */
		StreamUtils.stream_read_uint8(qtmovie.qtstream);
		size_remaining -= 1;
		/* flags */
		StreamUtils.stream_read_uint8(qtmovie.qtstream);
		StreamUtils.stream_read_uint8(qtmovie.qtstream);
		StreamUtils.stream_read_uint8(qtmovie.qtstream);
		size_remaining -= 3;

		/* default sample size */
		uniform_size = StreamUtils.stream_read_uint32(qtmovie.qtstream);
		if (uniform_size != 0)
		{
			/*
			** Normally files have variable sample sizes, this handles the case where
			** they are all the same size
			*/
	
			var uniform_num : Int = 0;
			
			uniform_num = StreamUtils.stream_read_uint32(qtmovie.qtstream);
			
			qtmovie.res.num_sample_byte_sizes = uniform_num;
			
			for (i in 0 ... uniform_num)
			{
				qtmovie.res.sample_byte_size[i] = uniform_size;
			}
			size_remaining -= 4;
			return;
		}
		size_remaining -= 4;

		try
		{
			numentries = StreamUtils.stream_read_uint32(qtmovie.qtstream);
		}
		catch(err: Dynamic)
		{
			trace("(read_chunk_stsz) error reading numentries - possibly number too large");
			numentries = 0;
		}

		size_remaining -= 4;

		qtmovie.res.num_sample_byte_sizes = numentries;

		for (i in 0 ... numentries)
		{
			qtmovie.res.sample_byte_size[i] = StreamUtils.stream_read_uint32(qtmovie.qtstream);

			size_remaining -= 4;
		}

		if (size_remaining != 0)
		{
			trace("(read_chunk_stsz) size remaining?");
			StreamUtils.stream_skip(qtmovie.qtstream, size_remaining);
		}
	}

	static function read_chunk_stbl(qtmovie : QTMovieT, chunk_len : Int) : Int
	{
		var size_remaining : Int = chunk_len - 8; // FIXME WRONG

		while (size_remaining != 0)
		{
			var sub_chunk_len : Int;
			var sub_chunk_id : haxe.Int32 = 0;
			
			try
			{
				sub_chunk_len = StreamUtils.stream_read_uint32(qtmovie.qtstream);
			}
			catch(err: Dynamic)
			{
				trace("(read_chunk_stbl) error reading sub_chunk_len - possibly number too large");
				sub_chunk_len = 0;
			}

			if (sub_chunk_len <= 1 || sub_chunk_len > size_remaining)
			{
				trace("strange size for chunk inside stbl " + sub_chunk_len + " (remaining: " + size_remaining + ")");
				return 0;
			}

			sub_chunk_id = StreamUtils.stream_read_uint32(qtmovie.qtstream);

			if(haxe.Int32.ucompare(sub_chunk_id, MakeFourCC32(115,116,115,100) ) == 0 )	// fourcc equals stsd
			{
				if (read_chunk_stsd(qtmovie, sub_chunk_len) == 0)
					return 0;
			}
			else if(haxe.Int32.ucompare(sub_chunk_id, MakeFourCC32(115,116,116,115) ) == 0 )	// fourcc equals stts
			{
				read_chunk_stts(qtmovie, sub_chunk_len);
			}
			else if(haxe.Int32.ucompare(sub_chunk_id, MakeFourCC32(115,116,115,122) ) == 0 )	// fourcc equals stsz
			{
				read_chunk_stsz(qtmovie, sub_chunk_len);
			}
			else if(haxe.Int32.ucompare(sub_chunk_id, MakeFourCC32(115,116,115,99) ) == 0 )	// fourcc equals stsc
			{
				/* skip these, no indexing for us! */
				StreamUtils.stream_skip(qtmovie.qtstream, sub_chunk_len - 8);
			}
			else if(haxe.Int32.ucompare(sub_chunk_id, MakeFourCC32(115,116,99,111) ) == 0 )	// fourcc equals stco
			{
				/* skip these, no indexing for us! */
				StreamUtils.stream_skip(qtmovie.qtstream, sub_chunk_len - 8);
			}
			else
			{
				trace("(stbl) unknown chunk id");
				return 0;
			}

			size_remaining -= sub_chunk_len;
		}

		return 1;
	}

	static function read_chunk_minf(qtmovie : QTMovieT, chunk_len : Int) : Int
	{
		var dinf_size : Int;
		var stbl_size : Int;
		var size_remaining : Int = chunk_len - 8; // FIXME WRONG
		var media_info_size : Int;

	  /**** SOUND HEADER CHUNK ****/
	  
	  	try
		{
			media_info_size = StreamUtils.stream_read_uint32(qtmovie.qtstream);
		}
		catch(err: Dynamic)
		{
			trace("(read_chunk_minf) error reading media_info_size - possibly number too large");
			media_info_size = 0;
		}
				
		if (media_info_size != 16)
		{
			trace("unexpected size in media info\n");
			return 0;
		}
		if (haxe.Int32.ucompare(StreamUtils.stream_read_uint32(qtmovie.qtstream), MakeFourCC32(115,109,104,100)) != 0)	// "smhd" ascii values
		{
			trace("not a sound header! can't handle this.");
			return 0;
		}
		/* now skip the rest */
		StreamUtils.stream_skip(qtmovie.qtstream, 16 - 8);
		size_remaining -= 16;
	  /****/

	  /**** DINF CHUNK ****/

	  	try
		{
			dinf_size = StreamUtils.stream_read_uint32(qtmovie.qtstream);
		}
		catch(err: Dynamic)
		{
			trace("(read_chunk_minf) error reading dinf_size - possibly number too large");
			dinf_size = 0;
		}	  

		if (haxe.Int32.ucompare(StreamUtils.stream_read_uint32(qtmovie.qtstream), MakeFourCC32(100,105,110,102)) != 0)	// "dinf" ascii values
		{
			trace("expected dinf, didn't get it.");
			return 0;
		}
		/* skip it */
		StreamUtils.stream_skip(qtmovie.qtstream, dinf_size - 8);
		size_remaining -= dinf_size;
	  /****/


	  /**** SAMPLE TABLE ****/
	  	try
		{
			stbl_size = StreamUtils.stream_read_uint32(qtmovie.qtstream);
		}
		catch(err: Dynamic)
		{
			trace("(read_chunk_minf) error reading stbl_size - possibly number too large");
			stbl_size = 0;
		}	
		
		if (haxe.Int32.ucompare(StreamUtils.stream_read_uint32(qtmovie.qtstream), MakeFourCC32(115,116,98,108)) != 0)	// "stbl" ascii values
		{
			trace("expected stbl, didn't get it.");
			return 0;
		}
		if (read_chunk_stbl(qtmovie, stbl_size) == 0)
			return 0;
		size_remaining -= stbl_size;

		if (size_remaining != 0)
		{
			trace("(read_chunk_minf) - size remaining?");
			StreamUtils.stream_skip(qtmovie.qtstream, size_remaining);
		}

		return 1;
	}

	static function read_chunk_mdia(qtmovie : QTMovieT, chunk_len : Int) : Int
	{
		var size_remaining : Int = chunk_len - 8; // FIXME WRONG

		while (size_remaining != 0)
		{
			var sub_chunk_len : Int;
			var sub_chunk_id  : haxe.Int32 = 0;

			try
			{
				sub_chunk_len = StreamUtils.stream_read_uint32(qtmovie.qtstream);
			}
			catch(err: Dynamic)
			{
				trace("(read_chunk_mdia) error reading sub_chunk_len - possibly number too large");
				sub_chunk_len = 0;
			}			

			if (sub_chunk_len <= 1 || sub_chunk_len > size_remaining)
			{
				trace("strange size for chunk inside mdia\n");
				return 0;
			}

			sub_chunk_id = StreamUtils.stream_read_uint32(qtmovie.qtstream);

			if(haxe.Int32.ucompare(sub_chunk_id, MakeFourCC32(109,100,104,100) ) == 0 )	// fourcc equals mdhd
			{
				read_chunk_mdhd(qtmovie, sub_chunk_len);
			}
			else if(haxe.Int32.ucompare(sub_chunk_id, MakeFourCC32(104,100,108,114) ) == 0 )	// fourcc equals hdlr
			{
				read_chunk_hdlr(qtmovie, sub_chunk_len);
			}
			else if(haxe.Int32.ucompare(sub_chunk_id, MakeFourCC32(109,105,110,102) ) == 0 )	// fourcc equals minf
			{
				if (read_chunk_minf(qtmovie, sub_chunk_len) == 0)
					return 0;
			}
			else
			{
				trace("(mdia) unknown chunk id");
				return 0;
			}

			size_remaining -= sub_chunk_len;
		}

		return 1;
	}

	/* 'trak' - a movie track - contains other atoms */
	static function read_chunk_trak(qtmovie : QTMovieT, chunk_len : Int) : Int
	{
		var size_remaining : Int = chunk_len - 8; // FIXME WRONG

		while (size_remaining != 0)
		{
			var sub_chunk_len : Int;
			var sub_chunk_id : haxe.Int32 = 0;

			try
			{
				sub_chunk_len = StreamUtils.stream_read_uint32(qtmovie.qtstream);
			}
			catch(err: Dynamic)
			{
				trace("(read_chunk_trak) error reading sub_chunk_len - possibly number too large");
				sub_chunk_len = 0;
			}			

			if (sub_chunk_len <= 1 || sub_chunk_len > size_remaining)
			{
				trace("strange size for chunk inside trak");
				return 0;
			}

			sub_chunk_id = StreamUtils.stream_read_uint32(qtmovie.qtstream);

			if(haxe.Int32.ucompare(sub_chunk_id, MakeFourCC32(116,107,104,100) ) == 0 )	// fourcc equals tkhd
			{
				read_chunk_tkhd(qtmovie, sub_chunk_len);
			}
			else if(haxe.Int32.ucompare(sub_chunk_id, MakeFourCC32(109,100,105,97) ) == 0 )	// fourcc equals mdia
			{
				if (read_chunk_mdia(qtmovie, sub_chunk_len) == 0)
					return 0;
			}
			else if(haxe.Int32.ucompare(sub_chunk_id, MakeFourCC32(101,100,116,115) ) == 0 )	// fourcc equals edts
			{
				read_chunk_edts(qtmovie, sub_chunk_len);
			}
			else
			{
				trace("(trak) unknown chunk id");
				return 0;
			}

			size_remaining -= sub_chunk_len;
		}

		return 1;
	}

	/* 'mvhd' movie header atom */
	static function read_chunk_mvhd(qtmovie : QTMovieT, chunk_len : Int) : Void
	{
		/* don't need anything from here atm, skip */
		var size_remaining : Int = chunk_len - 8; // FIXME WRONG

		StreamUtils.stream_skip(qtmovie.qtstream, size_remaining);
	}

	/* 'udta' user data.. contains tag info */
	static function read_chunk_udta(qtmovie : QTMovieT, chunk_len : Int) : Void
	{
		/* don't need anything from here atm, skip */
		var size_remaining : Int = chunk_len - 8; // FIXME WRONG

		StreamUtils.stream_skip(qtmovie.qtstream, size_remaining);
	}

	/* 'iods' */
	static function read_chunk_iods(qtmovie : QTMovieT, chunk_len : Int) : Void
	{
		/* don't need anything from here atm, skip */
		var size_remaining : Int = chunk_len - 8; // FIXME WRONG

		StreamUtils.stream_skip(qtmovie.qtstream, size_remaining);
	}

	/* 'moov' movie atom - contains other atoms */
	static function read_chunk_moov(qtmovie : QTMovieT, chunk_len : Int) : Int
	{
		var size_remaining : Int = chunk_len - 8; // FIXME WRONG

		while (size_remaining != 0)
		{
			var sub_chunk_len : Int;
			var sub_chunk_id : haxe.Int32 = 0;
			
			try
			{
				sub_chunk_len = StreamUtils.stream_read_uint32(qtmovie.qtstream);
			}
			catch(err: Dynamic)
			{
				trace("(read_chunk_moov) error reading sub_chunk_len - possibly number too large");
				sub_chunk_len = 0;
			}			

			if (sub_chunk_len <= 1 || sub_chunk_len > size_remaining)
			{
				trace("strange size for chunk inside moov");
				return 0;
			}

			sub_chunk_id = StreamUtils.stream_read_uint32(qtmovie.qtstream);

			if(haxe.Int32.ucompare(sub_chunk_id, MakeFourCC32(109,118,104,100) ) == 0 )	// fourcc equals mvhd
			{
				read_chunk_mvhd(qtmovie, sub_chunk_len);
			}
			else if(haxe.Int32.ucompare(sub_chunk_id, MakeFourCC32(116,114,97,107) ) == 0 )	// fourcc equals trak
			{
				if (read_chunk_trak(qtmovie, sub_chunk_len) == 0)
					return 0;
			}
			else if(haxe.Int32.ucompare(sub_chunk_id, MakeFourCC32(117,100,116,97) ) == 0 )	// fourcc equals udta
			{
				read_chunk_udta(qtmovie, sub_chunk_len);
			}
			else if(haxe.Int32.ucompare(sub_chunk_id, MakeFourCC32(101,108,115,116) ) == 0 )	// fourcc equals elst
			{
				read_chunk_elst(qtmovie, sub_chunk_len);
			}
			else if(haxe.Int32.ucompare(sub_chunk_id, MakeFourCC32(105,111,100,115) ) == 0 )	// fourcc equals iods
			{
				read_chunk_iods(qtmovie, sub_chunk_len);
			}
			else
			{
				trace("(moov) unknown chunk id: %c%c%c%c", (sub_chunk_id >> 24), (sub_chunk_id >> 16), (sub_chunk_id >> 8), sub_chunk_id);
				return 0;
			}

			size_remaining -= sub_chunk_len;
		}

		return 1;
	}

	static function read_chunk_mdat(qtmovie : QTMovieT, chunk_len : Int, skip_mdat : Int) : Void
	{
		var size_remaining : Int = chunk_len - 8; // FIXME WRONG

		if (size_remaining == 0)
			return;

		qtmovie.res.mdat_len = size_remaining;
		if (skip_mdat != 0)
		{
			qtmovie.saved_mdat_pos = StreamUtils.stream_tell(qtmovie.qtstream);

			StreamUtils.stream_skip(qtmovie.qtstream, size_remaining);
		}
	}

	static function set_saved_mdat(qtmovie : QTMovieT) : Int
	{
		// returns as follows
		// 1 - all ok
		// 2 - do not have valid saved mdat pos
		// 3 - have valid saved mdat pos, but cannot seek there - need to close/reopen stream

		if (qtmovie.saved_mdat_pos == -1)
		{
			trace("stream contains mdat before moov but is not seekable");
			return 2;
		}

		if (StreamUtils.stream_setpos(qtmovie.qtstream, qtmovie.saved_mdat_pos) != 0)
		{
			return 3;
		}

		return 1;
	}
}


