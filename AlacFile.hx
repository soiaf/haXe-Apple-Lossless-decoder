/*
** AlacFile.hx
**
** Copyright (c) 2011 Peter McQuillan
**
** All Rights Reserved.
**                       
** Distributed under the BSD Software License (see license.txt)  
**
*/

class AlacFile
{
#if flash10
	public var input_buffer : flash.Vector < Int >;
#else
	public var input_buffer : Array< Int >;
#end	
	public var ibIdx : Int;
	public var input_buffer_bitaccumulator : Int; /* used so we can do arbitary
												bit reads */

	public var samplesize : Int;
	public var numchannels : Int;
	public var bytespersample : Int;


	/* buffers */
	public var predicterror_buffer_a : Array < Int >;
	public var predicterror_buffer_b : Array < Int >;

	public var outputsamples_buffer_a : Array < Int >;
	public var outputsamples_buffer_b : Array < Int >;

	public var uncompressed_bytes_buffer_a : Array < Int >;
	public var uncompressed_bytes_buffer_b : Array < Int >;



  /* stuff from setinfo */
  public var setinfo_max_samples_per_frame : Int; // 0x1000 = 4096
	/* max samples per frame? */
  public var setinfo_7a : Int; // 0x00
  public var setinfo_sample_size : Int; // 0x10
  public var setinfo_rice_historymult : Int; // 0x28
  public var setinfo_rice_initialhistory : Int; // 0x0a
  public var setinfo_rice_kmodifier : Int; // 0x0e
  public var setinfo_7f : Int; // 0x02
  public var setinfo_80 : Int; // 0x00ff
  public var setinfo_82 : Int; // 0x000020e7
 /* max sample size?? */
  public var setinfo_86 : Int; // 0x00069fe4
 /* bit rate (avarge)?? */
  public var setinfo_8a_rate : Int; // 0x0000ac44
  /* end setinfo stuff */
  

	public function new()
	{
#if flash10
		input_buffer = new flash.Vector((1024 * 80),true);
#else	
		input_buffer = new Array();		// 1024 * 80
#end
		ibIdx = 0;
		predicterror_buffer_a = new Array();	// 4 * 4096
		predicterror_buffer_b = new Array();	// 4 * 4096

		outputsamples_buffer_a = new Array();	// 4 * 4096
		outputsamples_buffer_b = new Array();	// 4 * 4096

		uncompressed_bytes_buffer_a = new Array();	// 4 * 4096
		uncompressed_bytes_buffer_b = new Array();	// 4 * 4096
	}

}