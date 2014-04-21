/*
** DemuxResT.hx
**
** Copyright (c) 2011-2014 Peter McQuillan
**
** All Rights Reserved.
**                       
** Distributed under the BSD Software License (see license.txt)  
**
*/

class DemuxResT
{
	public var format_read : Int;

	public var num_channels : Int;
	public var sample_size : Int;
	public var sample_rate : Int;
	public var format : haxe.Int32;
	public var buf : Array < Int >;

	public var time_to_sample : Array < SampleInfo >;
	public var num_time_to_samples : Int;

	public var sample_byte_size : Array < Int >;
	public var num_sample_byte_sizes : Int;

	public var codecdata_len : Int;

#if flash10	
	public var codecdata : flash.Vector < Int >;
#else
	public var codecdata : Array < Int >;
#end

	public var mdat_len : Int;
	
	public function new()
	{
		buf = new Array();
		time_to_sample = new Array();
		// not sure how many of these I need, so make 16
		for(i in 0 ... 16)
		{
			time_to_sample[i] = new SampleInfo();
		}
		sample_byte_size = new Array();

#if flash10
		codecdata = new flash.Vector(1024,true);
#else		
		codecdata = new Array();
#end
		
		format = 0;
	}
}
