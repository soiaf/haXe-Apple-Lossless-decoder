/*
** TestFlash.hx
**
** Copyright (c) 2011-2014 Peter McQuillan
**
** All Rights Reserved.
**                       
** Distributed under the BSD Software License (see license.txt)  
**
*/

class TestFlash
{
	static var s : flash.media.Sound;
	var sch : flash.media.SoundChannel;
	var total_unpacked_samples : Float;
	static var num_channels : Int;
	static var bps : Int;
	static var currentBlock : Int;

	static var mc : flash.display.MovieClip;
	static var stage : Dynamic; 
	static var playBtn : flash.display.Sprite;
	static var stopBtn : flash.display.Sprite;
	static var te : flash.text.TextField;
	
	static var alac : AlacFile = new AlacFile();
	static var demux_res : DemuxResT;

	var fr : flash.net.FileReference;

	//File types which we want the user to open 

	private static var FILE_TYPES : Array <flash.net.FileFilter> = [new flash.net.FileFilter("Apple Lossless File", "*.m4a;*.M4A")]; 

	static var bistream;

	private function init_sound_converter(demux_res : DemuxResT) : Void
	{
		alac = AlacUtils.create_alac(demux_res.sample_size, demux_res.num_channels);

		AlacUtils.alac_set_info(alac, demux_res.codecdata);
	}

	private function onLoadComplete(e: flash.events.Event) : Void 
	{
	
		var qtmovie : QTMovieT = new QTMovieT();
		var headerRead : Int;
		var errorState = 0;
		
		te.text = "File loaded\n";
 //       te.text = te.text + "total num of bytes in ALAC file " + fr.size + "\n";

		var filebytes = haxe.io.Bytes.ofData(fr.data);  
		var sampleRate : Int;

		demux_res = new DemuxResT();
		currentBlock = 0;

        fr = null;

        bistream = new haxe.io.BytesInput(filebytes, 0);
		
		headerRead = DemuxUtils.qtmovie_read(bistream, qtmovie, demux_res);

		if (headerRead == 1)
		{
			trace("ok so far");
		}
		else if(headerRead == 3)
		{
			bistream.close();
			bistream = new haxe.io.BytesInput(filebytes, 0);
			qtmovie.qtstream.stream = bistream;
			qtmovie.qtstream.currentPos = 0;
			StreamUtils.stream_skip(qtmovie.qtstream, qtmovie.saved_mdat_pos);
		}
		else
		{
			errorState = 1;
		}
	
		if (demux_res.format_read == 0)
		{	
			errorState = 1;
		}
		
        if (errorState == 1)
        {
            te.text = te.text + "Sorry an error has occured\n";
            te.text = te.text + "Please select a new Apple Lossless file";
          
            playBtn.visible = true;
            stopBtn.visible = false;
        }
        else
        {			
			init_sound_converter(demux_res);
			
            num_channels = demux_res.num_channels;

            te.text = te.text + "The ALAC file has " + num_channels + " channels\n";

            total_unpacked_samples = 0;

            sampleRate = demux_res.sample_rate;

            if(sampleRate != 44100)
            {
                te.text = te.text + "The sample rate for this file is " + sampleRate + "\n";
                te.text = te.text + "Please note that this sample rate is not supported and\n";
                te.text = te.text + "your file will not be played back correctly\n";
            }
     

            bps = Std.int(demux_res.sample_size / 8);

            if(bps != 2 || num_channels==1)
            {
                te.text = te.text + "Sorry, but this Flash demo player only supports 16-bit\n";
                te.text = te.text + "stereo ALAC files. Please select a new file to play\n";
                playBtn.visible = true;
                stopBtn.visible = false;
            }
            else
            {
                s = new flash.media.Sound();
                play();
            }
        }
    }
    
    public function play() : Void 
    {
       // trace("adding callback");
        s.addEventListener("sampleData", sample_unpacker);
        te.text = te.text + "Now Playing\n";
        stopBtn.visible = true;
        sch = s.play();
    }


    static public function stop() : Void
    {
        if ( null != s ) 
        {
            s.removeEventListener("sampleData", sample_unpacker);
            s = null;
        }
        te.text = "Song complete. Please select a new file.";

        playBtn.visible = true;
        stopBtn.visible = false;

    }

		static function get_sample_info(demux_res : DemuxResT, samplenum: Int, sampleinfo : SampleDuration) : Int
	{
		var duration_index_accum : Int = 0;
		var duration_cur_index : Int = 0;

		if (samplenum >= demux_res.num_sample_byte_sizes)
		{
			trace("sample " + samplenum + " does not exist ");
			return 0;
		}

		if (demux_res.num_time_to_samples == 0)		// was null
		{
			trace("no time to samples");
			return 0;
		}
		while ((demux_res.time_to_sample[duration_cur_index].sample_count + duration_index_accum) <= samplenum)
		{
			duration_index_accum += demux_res.time_to_sample[duration_cur_index].sample_count;
			duration_cur_index++;
			if (duration_cur_index >= demux_res.num_time_to_samples)
			{
				trace("sample " + samplenum + " does not have a duration");
				return 0;
			}
		}

		sampleinfo.sample_duration = demux_res.time_to_sample[duration_cur_index].sample_duration;
		sampleinfo.sample_byte_size = demux_res.sample_byte_size[samplenum];

		return 1;
	}


    static function sample_unpacker(event : flash.events.SampleDataEvent) : Void 
    {
        var start : Float = 0;
        var end : Float = 0;
        var total_unpacked_samples : Float = 0;
		var divisor : Float = 0;
		var sampleinfo : SampleDuration = new SampleDuration();
		var buffer_size : Int = 1024 *80; // sample big enough to hold any input for a single alac frame
		var buffer : flash.Vector < Int > = new flash.Vector(buffer_size,true);
		var inputStream : MyStream = new MyStream();
		var destBufferSize : Int = 1024 *24;
		var pDestBuffer : flash.Vector < Int > = new flash.Vector(destBufferSize,true);
		var outputBytes : Int;
		
		inputStream.stream = bistream;
 

		divisor = 32767.0;	// 2 to power 15 minus 1


        try
        {
            var samples_unpacked : Float;
            var bytesToWrite : Int = 0;
            var x : Int = 1;
			var sample_byte_size : Int = 0;
			var sample_duration : Int = 0;
			var playbackSample : Int = 0;
			
			if (get_sample_info(demux_res, currentBlock, sampleinfo) == 0)
			{
				stop();
			}
			currentBlock++;
			
			sample_duration = sampleinfo.sample_duration;
			sample_byte_size = sampleinfo.sample_byte_size;
			
			StreamUtils.stream_read(inputStream, sample_byte_size, buffer,0);
			
			outputBytes = AlacUtils.decode_frame(alac, buffer, pDestBuffer, destBufferSize);		


			outputBytes = Std.int(outputBytes/2);

            total_unpacked_samples += outputBytes;

            if(outputBytes == 0)
            {
                stop();
            }

            if (outputBytes > 0)
            {

               // Currently assumption is 16 or 24 bit 44.1 kHz
               // Flash assumes values will be floats with values less than 1.0
               // Our buffer already has the data in the form LRLRLR... so we can
               // directly use the data, we just need to convert the values
 
               bytesToWrite = outputBytes;


				for(i in 0 ... bytesToWrite)
				{
					untyped { 
						event.data.writeFloat(pDestBuffer[i] / divisor); 
					};
				}
            }
            

            if(outputBytes < 8192 )
            {
			    for(i in 0 ... 8192)
                {
                    event.data.writeFloat(0.0);
                }
            }
	
        }
        catch (err: Dynamic)
        {
            var es = haxe.CallStack.exceptionStack();
            te.text = te.text + haxe.CallStack.toString(es) + "\n";
            te.text = te.text + "Error when extracting ALAC data, sorry";           
        }

    }


    private function new() 
    {
    }

    static function check_version() : Bool {
        if (flash.Lib.current.loaderInfo.parameters.noversioncheck != null)
            return true;

        var vs : String = flash.system.Capabilities.version;
        var vns : String = vs.split(" ")[1];
        var vn : Array<String> = vns.split(",");

        if (vn.length < 1 || Std.parseInt(vn[0]) < 10)
            return false;

        if (vn.length < 2 || Std.parseInt(vn[1]) > 0)
            return true;

        if (vn.length < 3 || Std.parseInt(vn[2]) > 0)
            return true;

        if (vn.length < 4 || Std.parseInt(vn[3]) >= 525)
            return true;

        return false;
    }

    private function onCancel(e: flash.events.Event): Void 
    { 
        te.text = "File Browse Canceled"; 
        fr = null; 
        playBtn.visible = true;
        stopBtn.visible = false;
    } 


    //called when the user selects a file from the browse dialog 

    private function onFileSelect(e: flash.events.Event): Void 
    { 
        //listen for when the file has loaded 

        fr.addEventListener(flash.events.Event.COMPLETE, onLoadComplete); 

        //listen for any errors reading the file 

        fr.addEventListener(flash.events.IOErrorEvent.IO_ERROR, onLoadError); 

        //load the content of the file 

        fr.load(); 

    }

    //called if an error occurs while loading the file contents

    private function onLoadError(e: flash.events.IOErrorEvent):Void 
    { 
        te.text = "Error loading file : " + e.text; 
        playBtn.visible = true;
        stopBtn.visible = false;
    }



    function lets_go() : Void
    {

       //create the FileReference instance 
           
       fr = new flash.net.FileReference(); 
            
       //listen for when they select a file 

       fr.addEventListener(flash.events.Event.SELECT, onFileSelect); 

       //listen for when then cancel out of the browse dialog 

       fr.addEventListener(flash.events.Event.CANCEL,onCancel); 

       //open a native browse dialog that filters for ALAC files 

       fr.browse(FILE_TYPES);

    }
    
    static function overEntry(event : flash.events.MouseEvent)
    {
        playBtn.alpha=0.9;
    }
  
    static function outEntry(event:flash.events.MouseEvent)
    {
        playBtn.alpha=0.7;
    }
    
    // triggered when play button is clicked
  
    static function downEntry(event:flash.events.MouseEvent)
    {
        playBtn.visible = false;
        var tf = new TestFlash();
        tf.lets_go();
    }

    static function overStopEntry(event : flash.events.MouseEvent)
    {
        stopBtn.alpha=0.9;
    }
  
    static function outStopEntry(event:flash.events.MouseEvent)
    {
        stopBtn.alpha=0.7;
    }
    
    // triggered when stop button is clicked
  
    static function downStopEntry(event:flash.events.MouseEvent)
    {
        stopBtn.visible = false;
        playBtn.visible = true;

        if ( null != s ) 
        {
            s.removeEventListener("sampleData", sample_unpacker);
            s = null;
        }

        te.text = "Song stopped. Please select a new file.";
    }


    public static function main()
    {

        if (check_version()) 
        {
        
            // Thanks to http://lionpath.com/haxeflashtutorial/release/chap01.html 
            // for the play button code which I've used here
            
			mc = flash.Lib.current; 
			stage = mc.stage; 
			var g : flash.display.Graphics;

			te = new flash.text.TextField();

			te.autoSize = flash.text.TextFieldAutoSize.LEFT;
            te.y=80;
			mc.addChild(te);

			te.text = "Apple Lossless decoder flash demo (c) 2014 Peter McQuillan\n\n";
            te.text = te.text + "Click the Play button to select a Apple Lossless file to listen to\n";
            te.text = te.text + "ALAC file should be a 16bit 44.1kHz file (normal CD)";
 
            playBtn = new flash.display.Sprite(); 

            g = playBtn.graphics;
            g.lineStyle(1,0xe5e5e5);
            
            var w : Int = 60;
            var h : Int = 40;
            var colors : Array <UInt> = [0xF5F5F5, 0xA0A0A0];
            var alphas : Array <Int>  = [1, 1];
            var ratios : Array <Int> = [0, 255];
            var matrix : flash.geom.Matrix = new flash.geom.Matrix();
            
            matrix.createGradientBox(w-2, h-2, Math.PI/2, 0, 0);
            g.beginGradientFill(flash.display.GradientType.LINEAR, 
                                colors,
                                alphas,
                                ratios, 
                                matrix, 
                                flash.display.SpreadMethod.PAD, 
                                flash.display.InterpolationMethod.LINEAR_RGB, 
                                0);
            g.drawRoundRect(0,0,w,h,16,16);
            g.endFill();
    
            // draw a triangle
            g.lineStyle(1,0x808080);
            g.beginFill(0x0);
            g.moveTo((w-20)/2,5);
            g.lineTo((w-20)/2+20,h/2);
            g.lineTo((w-20)/2,h-5);
            g.lineTo((w-20)/2,5);
            g.endFill();
    
            // add the drop-shadow filter
            var shadow : flash.filters.DropShadowFilter = new flash.filters.DropShadowFilter(
            4,45,0x000000,0.8,
            4,4,
            0.65, flash.filters.BitmapFilterQuality.HIGH, false, false
            );
    
            var af : Array < flash.filters.BitmapFilter > = new Array();
            af.push(shadow);
            playBtn.filters = af;
            playBtn.alpha = 0.5;
            playBtn.x = 10;
            playBtn.y = 10;


            // add the event listener 
            playBtn.addEventListener(flash.events.MouseEvent.MOUSE_OUT, outEntry); 
            playBtn.addEventListener(flash.events.MouseEvent.MOUSE_OVER, overEntry); 
            playBtn.addEventListener(flash.events.MouseEvent.MOUSE_DOWN, downEntry); 

            mc.addChild(playBtn); 

            stopBtn = new flash.display.Sprite(); 

            g = stopBtn.graphics;
            g.lineStyle(1,0xe5e5e5);
            
            matrix = new flash.geom.Matrix();
            
            matrix.createGradientBox(w-2, h-2, Math.PI/2, 0, 0);
            g.beginGradientFill(flash.display.GradientType.LINEAR, 
                                colors,
                                alphas,
                                ratios, 
                                matrix, 
                                flash.display.SpreadMethod.PAD, 
                                flash.display.InterpolationMethod.LINEAR_RGB, 
                                0);
            g.drawRoundRect(0,0,w,h,16,16);
            g.endFill();
    
            // draw a smaller square
            g.lineStyle(1,0x808080);
            g.beginFill(0x0);
            g.drawRect( (w-25)/2 ,9,25,22);
            g.endFill();
    
            // add the drop-shadow filter
            var shadow : flash.filters.DropShadowFilter = new flash.filters.DropShadowFilter(
            4,45,0x000000,0.8,
            4,4,
            0.65, flash.filters.BitmapFilterQuality.HIGH, false, false
            );
    
            var af : Array < flash.filters.BitmapFilter > = new Array();
            af.push(shadow);
            stopBtn.filters = af;
            stopBtn.alpha = 0.5;
            stopBtn.x = 10;
            stopBtn.y = 10;


            // add the event listener 
            stopBtn.addEventListener(flash.events.MouseEvent.MOUSE_OUT, outStopEntry); 
            stopBtn.addEventListener(flash.events.MouseEvent.MOUSE_OVER, overStopEntry); 
            stopBtn.addEventListener(flash.events.MouseEvent.MOUSE_DOWN, downStopEntry); 

            mc.addChild(stopBtn); 

            stopBtn.visible = false;

        } 
        else 
        {
            trace("You need a newer Flash Player.");
            trace("Your version: " + flash.system.Capabilities.version);
            trace("The minimum required version: 10.0.0.525");
        }
       
    }
}
