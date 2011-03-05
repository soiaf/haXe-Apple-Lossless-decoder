/*
** MyStream.hx
**
** Copyright (c) 2011 Peter McQuillan
**
** All Rights Reserved.
**                       
** Distributed under the BSD Software License (see license.txt)  
**
*/

class MyStream
{
	public var stream : haxe.io.Input;
	public var currentPos : Int;

	public function new()
	{
		currentPos = 0;
	}
}