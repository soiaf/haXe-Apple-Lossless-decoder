/*
** QTMovieT.hx
**
** Copyright (c) 2011-2014 Peter McQuillan
**
** All Rights Reserved.
**                       
** Distributed under the BSD Software License (see license.txt)  
**
*/

class QTMovieT
{
	public var qtstream : MyStream;
	public var res : DemuxResT;
	public var saved_mdat_pos : Int;

	public function new()
	{
		res = new DemuxResT();
		saved_mdat_pos = 0;
		qtstream = new MyStream();
	}
}
