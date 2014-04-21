/*
** Main.hx
**
** Copyright (c) 2011-2014 Peter McQuillan
**
** All Rights Reserved.
**                       
** Distributed under the BSD Software License (see license.txt)  
**
*/

class Main
{
	static var alac : AlacFile = new AlacFile();

	static var input_opened : Int;
	static var input_stream;

	static var output_stream;
	static var output_opened : Int;

	static var write_wav_format : Int = 1;
	static var verbose : Int = 0;
	static var test_file_type : Int = 0;

	static var input_file_n : String = "";
	static var output_file_n : String = "";


    // Reformat samples from longs in processor's native endian mode to
    // little-endian data with (possibly) less than 3 bytes / sample.

    public static function format_samples(bps : Int, src : Array < Int >, samcnt : Int) : Array < Int >
    {
        var temp : Int = 0;
        var counter : Int = 0;
        var counter2 : Int = 0;
        var dst : Array < Int > = new Array();
        dst[1024 * 24] = 0;	// pre-size the array

        switch (bps)
        {
            case 1:
                while (samcnt > 0)
                {
                    dst[counter] =  (0x00FF & (src[counter] + 128));
                    counter++;
                    samcnt--;
                }

			case 2:
				while (samcnt > 0)
				{
					temp = src[counter2];
					dst[counter] =  temp;
					counter++;
					dst[counter] =  (temp >>> 8);
					counter++;
					counter2++;
					samcnt = samcnt - 2;
                }

            case 3:
                while (samcnt > 0)
                {
                    dst[counter] =  src[counter2];
                    counter++;
                    counter2++;
                    samcnt--;
                }
        }

        return dst;
    }

	static function get_sample_info(demux_res : DemuxResT, samplenum: Int, sampleinfo : SampleDuration) : Int
	{
		var duration_index_accum : Int = 0;
		var duration_cur_index : Int = 0;

		if (samplenum >= demux_res.num_sample_byte_sizes)
		{
			Sys.println("sample " + samplenum + " does not exist ");
			return 0;
		}

		if (demux_res.num_time_to_samples == 0)		// was null
		{
			Sys.println("no time to samples");
			return 0;
		}
		while ((demux_res.time_to_sample[duration_cur_index].sample_count + duration_index_accum) <= samplenum)
		{
			duration_index_accum += demux_res.time_to_sample[duration_cur_index].sample_count;
			duration_cur_index++;
			if (duration_cur_index >= demux_res.num_time_to_samples)
			{
				Sys.println("sample " + samplenum + " does not have a duration");
				return 0;
			}
		}

		sampleinfo.sample_duration = demux_res.time_to_sample[duration_cur_index].sample_duration;
		sampleinfo.sample_byte_size = demux_res.sample_byte_size[samplenum];

		return 1;
	}
	
	static function setup_environment(argc : Int, argv : Array <String>) : Void
	{
		var i = argc;

		var escaped : Int = 0;

		if (argc < 2)
			usage();

		var arg_idx:Int= 0;
		// loop through command-line arguments
		while (arg_idx < Sys.args().length)
		{
			if (StringTools.startsWith(Sys.args()[arg_idx], "-"))
			{
				if (StringTools.startsWith(Sys.args()[arg_idx], "-r") || StringTools.startsWith(Sys.args()[arg_idx], "-R") )
				{
					// raw PCM output
					write_wav_format = 0;
				}
				if (StringTools.startsWith(Sys.args()[arg_idx], "-v") || StringTools.startsWith(Sys.args()[arg_idx], "-V") )
				{
					// verbose
					verbose = 1;
				}
				if (StringTools.startsWith(Sys.args()[arg_idx], "-t") || StringTools.startsWith(Sys.args()[arg_idx], "-T") )
				{
					// test file type
					test_file_type = 1;
				}
			}
			else if (input_file_n.length == 0)
			{
				input_file_n = Sys.args()[arg_idx];
			}
			else if (output_file_n.length == 0)
			{
				output_file_n = Sys.args()[arg_idx];
			}
			else
			{
				Sys.println("extra unknown argument: " + Sys.args()[arg_idx]);
				usage();
			}
			arg_idx++;
		}

		if (input_file_n.length == 0 || output_file_n.length == 0)
			usage();

		if (output_file_n.length != 0)
		{
			// should probably check if file already exists here

			output_stream = sys.io.File.write(output_file_n,true);

			output_opened = 1;
		}

		input_stream = sys.io.File.read(input_file_n,true);

		input_opened = 1;
	}

	static function GetBuffer(demux_res : DemuxResT) : Void
	{
		var destBufferSize : Int = 1024 *24; // 24kb buffer = 4096 frames = 1 alac sample (we support max 24bps)
		var pcmBuffer : Array < Int > = new Array();
		var inputStream : MyStream = new MyStream();

		pcmBuffer[1024 * 24] = 0;	// presize array
		
		var pDestBuffer : Array < Int > = new Array(); 

		var bytes_read : Int = 0;

		var buffer_size : Int = 1024 *80; // sample big enough to hold any input for a single alac frame

		var i : Int = 0;

		var buffer : Array < Int > = new Array();

		var bps : Int = 2; 

		if(alac.setinfo_sample_size == 24)
		{
			bps = 3;
		}
		
		inputStream.stream = input_stream;

		for(i in 0 ... demux_res.num_sample_byte_sizes)
		{
			var sample_duration : Int = 0;
			var sample_byte_size : Int = 0;
			var sampleinfo : SampleDuration = new SampleDuration();

			var outputBytes : Int;

			/* just get one sample for now */
			if (get_sample_info(demux_res, i, sampleinfo) == 0)
			{
				Sys.println("sample failed");
				return;
			}

			sample_duration = sampleinfo.sample_duration;
			sample_byte_size = sampleinfo.sample_byte_size;

			if (buffer_size < sample_byte_size)
			{
				Sys.println("sorry buffer too small! (is " + buffer_size + " want " + sample_byte_size + ")");
				return;
			}

			StreamUtils.stream_read(inputStream, sample_byte_size, buffer,0);

			/* now fetch */
			outputBytes = destBufferSize;

			outputBytes = AlacUtils.decode_frame(alac, buffer, pDestBuffer, outputBytes);

			/* write */
			bytes_read += outputBytes;

			if (verbose != 0)
				Sys.println("read " + outputBytes + " bytes. total: " + bytes_read);
				
			pcmBuffer = format_samples(bps, pDestBuffer, outputBytes);


			var buffAsBytes = haxe.io.Bytes.alloc(outputBytes);
			
			for(i in 0 ... outputBytes)
			{
				buffAsBytes.set(i,pcmBuffer[i]);		
			}

			output_stream.writeBytes(buffAsBytes, 0, outputBytes );
		}
		if (verbose != 0)
			Sys.println("done reading, read " + i + " frames");
	}

	static function init_sound_converter(demux_res : DemuxResT) : Void
	{
		alac = AlacUtils.create_alac(demux_res.sample_size, demux_res.num_channels);

		AlacUtils.alac_set_info(alac, demux_res.codecdata);
	}

	static function usage() : Void
	{
		Sys.println("Usage: alac [options] inputfile outputfile");
		Sys.println("Decompresses the ALAC file specified");
		Sys.println("Options:");
		Sys.println("  -r                write output as raw PCM data. Default");
		Sys.println("                    is in WAV format.");
		Sys.println("  -v                verbose output.");
		Sys.println("  -t                test that file is ALAC, also tests for");
		Sys.println("                    other m4a file types.");
		Sys.println("");
		Sys.println("This port of the code is (c) 2014 Peter McQuillan");
		Sys.println("Original software is (c) 2005 David Hammerton");
		Sys.exit(1);
	}

	public static function main()
	{
		var demux_res : DemuxResT = new DemuxResT();
		var qtmovie : QTMovieT = new QTMovieT();
		var output_size : Int;
		var i : Int;
		var headerRead : Int;

		output_opened = 0;
		input_opened = 0;

		setup_environment(Sys.args().length, Sys.args());

		if (input_stream == null)
		{
			Sys.println("failed to create input stream from file");
			return 1;
		}

		/* if qtmovie_read returns successfully, the stream is up to
		 * the movie data, which can be used directly by the decoder */
		headerRead = DemuxUtils.qtmovie_read(input_stream, qtmovie, demux_res);

		if (headerRead == 0)
		{
			if (test_file_type == 0 || demux_res.format_read == 0)
			{
				Sys.println("failed to load the QuickTime movie headers");
				if (demux_res.format_read != 0)
					 Sys.println("file type: " + demux_res.format);
				else
					 Sys.println("");
				return 1;
			}
		}
		else if(headerRead == 3)
		{
			input_stream.close();
			input_stream = sys.io.File.read(input_file_n,true);
			qtmovie.qtstream.stream = input_stream;
			qtmovie.qtstream.currentPos = 0;
			StreamUtils.stream_skip(qtmovie.qtstream, qtmovie.saved_mdat_pos);
		}

		if (test_file_type != 0)
		{
			/* just in case: */
			if (demux_res.format_read == 0)
			{
				Sys.println("failed to load the QuickTime movie headers." + " Probably not a quicktime file");
				return 1;
			}
			Sys.println("file type: " + demux_res.format);
			/* now, we have to return useful return codes */
			
			if(haxe.Int32.ucompare(demux_res.format, DemuxUtils.MakeFourCC32(97,108,97,99) ) == 0 )		// "alac" ascii values
			{
				return 100;
			}
			else if(haxe.Int32.ucompare(demux_res.format, DemuxUtils.MakeFourCC32(109,112,52,97) ) == 0 )		// "mp4a" ascii values
			{
				return 100; // m4pa = unencrypted aac = 100
			}
			return 1;
		}

		/* initialise the sound converter */
		init_sound_converter(demux_res);

		/* write wav output headers */
		if (write_wav_format != 0)
		{
			/* calculate output size */
			output_size = 0;
			var thissample_duration : Int = 0;
			var thissample_bytesize  : Int= 0;
			var sampleinfo : SampleDuration = new SampleDuration();
			
			for(i in 0 ... demux_res.num_sample_byte_sizes)
			{
				thissample_duration = 0;
				thissample_bytesize = 0;

				get_sample_info(demux_res, i, sampleinfo);
				thissample_duration = sampleinfo.sample_duration;
				thissample_bytesize = sampleinfo.sample_byte_size;


				output_size += (thissample_duration * Std.int(demux_res.sample_size / 8) * demux_res.num_channels);
			}
			WavWriter.wavwriter_writeheaders(output_stream, output_size, demux_res.num_channels, demux_res.sample_rate, demux_res.sample_size);
		}

		/* will convert the entire buffer */
		GetBuffer(demux_res);

		if (output_opened != 0)
			output_stream.close();

		if (input_opened != 0)
			input_stream.close();

		return(0);

	}
}

