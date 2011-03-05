/*
** AlacUtils.hx
**
** Copyright (c) 2011 Peter McQuillan
**
** All Rights Reserved.
**                       
** Distributed under the BSD Software License (see license.txt)  
**
*/

class AlacUtils
{
#if flash10
	public static function alac_set_info(alac : AlacFile, inputbuffer : flash.Vector < Int >) : Void
#else
	public static function alac_set_info(alac : AlacFile, inputbuffer : Array < Int >) : Void
#end	
	{
	  var ptrIndex : Int = 0;
	  ptrIndex += 4; // size
	  ptrIndex += 4; // frma
	  ptrIndex += 4; // alac
	  ptrIndex += 4; // size
	  ptrIndex += 4; // alac

	  ptrIndex += 4; // 0 ?

	  alac.setinfo_max_samples_per_frame = ((inputbuffer[ptrIndex] << 24) + (inputbuffer[ptrIndex+1] << 16) + (inputbuffer[ptrIndex+2] << 8) + inputbuffer[ptrIndex+3]); // buffer size / 2 ?
	  ptrIndex += 4;
	  alac.setinfo_7a = inputbuffer[ptrIndex];
	  ptrIndex += 1;
	  alac.setinfo_sample_size = inputbuffer[ptrIndex];
	  ptrIndex += 1;
	  alac.setinfo_rice_historymult = inputbuffer[ptrIndex];
	  ptrIndex += 1;
	  alac.setinfo_rice_initialhistory = inputbuffer[ptrIndex];
	  ptrIndex += 1;
	  alac.setinfo_rice_kmodifier = inputbuffer[ptrIndex];
	  ptrIndex += 1;
	  alac.setinfo_7f = inputbuffer[ptrIndex];
	  ptrIndex += 1;
	  alac.setinfo_80 = (inputbuffer[ptrIndex] << 8) + inputbuffer[ptrIndex+1];
	  ptrIndex += 2;
	  alac.setinfo_82 = ((inputbuffer[ptrIndex] << 24) + (inputbuffer[ptrIndex+1] << 16) + (inputbuffer[ptrIndex+2] << 8) + inputbuffer[ptrIndex+3]);
	  ptrIndex += 4;
	  alac.setinfo_86 = ((inputbuffer[ptrIndex] << 24) + (inputbuffer[ptrIndex+1] << 16) + (inputbuffer[ptrIndex+2] << 8) + inputbuffer[ptrIndex+3]);
	  ptrIndex += 4;
	  alac.setinfo_8a_rate = ((inputbuffer[ptrIndex] << 24) + (inputbuffer[ptrIndex+1] << 16) + (inputbuffer[ptrIndex+2] << 8) + inputbuffer[ptrIndex+3]);
	  ptrIndex += 4;

	}

	/* stream reading */

	/* supports reading 1 to 16 bits, in big endian format */
	static function readbits_16(alac : AlacFile, bits : Int) : Int
	{
		var result : Int = 0;
		var new_accumulator : Int;
		var part1 : Int;
		var part2 : Int;
		var part3 : Int;
		
		part1 = alac.input_buffer[alac.ibIdx];
		part2 = alac.input_buffer[alac.ibIdx + 1];
		part3 = alac.input_buffer[alac.ibIdx + 2];

#if !flash10		
		if(part1==null)
			part1 = 0;

		if(part2==null)
			part2 = 0;
			
		if(part3==null)
			part3 = 0;			
#end
			
		result = ((part1 << 16) | (part2 << 8) | part3);

		/* shift left by the number of bits we've already read,
		 * so that the top 'n' bits of the 24 bits we read will
		 * be the return bits */
		result = result << alac.input_buffer_bitaccumulator;

		result = result & 0x00ffffff;

		/* and then only want the top 'n' bits from that, where
		 * n is 'bits' */
		result = result >> (24 - bits);

		new_accumulator = (alac.input_buffer_bitaccumulator + bits);

		/* increase the buffer pointer if we've read over n bytes. */
		alac.ibIdx += (new_accumulator >> 3);

		/* and the remainder goes back into the bit accumulator */
		alac.input_buffer_bitaccumulator = (new_accumulator & 7);

		return result;
	}

	/* supports reading 1 to 32 bits, in big endian format */
	static function readbits(alac : AlacFile, bits : Int) : Int
	{
		var result : Int = 0;

		if (bits > 16)
		{
			bits -= 16;

			result = readbits_16(alac, 16) << bits;
		}

		result |= readbits_16(alac, bits);

		return result;
	}

	/* reads a single bit */
	static function readbit(alac : AlacFile) : Int
	{
		var result : Int;
		var new_accumulator : Int;
		var part1 : Int;
		
		part1 = alac.input_buffer[alac.ibIdx];
	
#if !flash10	
		if(part1==null)
			part1 = 0;
#end

		result = part1;

		result = result << alac.input_buffer_bitaccumulator;

		result = result >> 7 & 1;

		new_accumulator = (alac.input_buffer_bitaccumulator + 1);

		alac.ibIdx += Std.int(new_accumulator / 8);

		alac.input_buffer_bitaccumulator = (new_accumulator % 8);

		return result;
	}

	static function unreadbits(alac : AlacFile, bits : Int) : Void
	{
		var new_accumulator : Int = (alac.input_buffer_bitaccumulator - bits);

		alac.ibIdx += (new_accumulator >> 3);

		alac.input_buffer_bitaccumulator = (new_accumulator & 7);
		if (alac.input_buffer_bitaccumulator < 0)
			alac.input_buffer_bitaccumulator *= -1;
	}

	static function count_leading_zeros_extra(curbyte: Int, output : Int) : LeadingZeros
	{
		var lz : LeadingZeros = new LeadingZeros();
			
		if ((curbyte & 0xf0)==0)
		{
			output += 4;
		}
		else
			curbyte = curbyte >> 4;

		if ((curbyte & 0x8) != 0)
		{
			lz.output = output;
			lz.curbyte = curbyte;
			return lz;
		}
		if ((curbyte & 0x4) != 0)
		{
			lz.output = output + 1;
			lz.curbyte = curbyte;
			return lz;
		}
		if ((curbyte & 0x2) != 0)
		{
			lz.output = output + 2;
			lz.curbyte = curbyte;
			return lz;
		}
		if ((curbyte & 0x1) != 0)
		{
			lz.output = output + 3;
			lz.curbyte = curbyte;
			return lz;
		}

		/* shouldn't get here: */

		lz.output = output + 4;
		lz.curbyte = curbyte;
		return lz;

	}
	static function count_leading_zeros(input : Int) : Int
	{
		var output : Int = 0;
		var curbyte : Int = 0;
		var lz : LeadingZeros = new LeadingZeros();

		curbyte = input >> 24;
		if (curbyte != 0)
		{
			lz = count_leading_zeros_extra(curbyte, output);
			output = lz.output;
			curbyte = lz.curbyte;
			return output;
		}
		output += 8;

		curbyte = input >> 16;
		if ((curbyte & 0xFF) != 0)
		{
			lz = count_leading_zeros_extra(curbyte, output);
			output = lz.output;
			curbyte = lz.curbyte;

			return output;
		}
		output += 8;

		curbyte = input >> 8;
		if ((curbyte & 0xFF) != 0)
		{
			lz = count_leading_zeros_extra(curbyte, output);
			output = lz.output;
			curbyte = lz.curbyte;

			return output;
		}
		output += 8;

		curbyte = input;
		if ((curbyte & 0xFF) != 0)
		{
			lz = count_leading_zeros_extra(curbyte, output);
			output = lz.output;
			curbyte = lz.curbyte;

			return output;
		}
		output += 8;

		return output;
	}

	public static function entropy_decode_value(alac : AlacFile, readSampleSize : Int, k : Int, rice_kmodifier_mask : Int) : Int
	{
		var x : Int = 0; // decoded value

		// read x, number of 1s before 0 represent the rice value.
		while (x <= Defines.RICE_THRESHOLD && readbit(alac) != 0)
		{
			x++;
		}

		if (x > Defines.RICE_THRESHOLD)
		{
			// read the number from the bit stream (raw value)
			var value : Int = 0;

			value = readbits(alac, readSampleSize);

			// mask value
			value &= ((0xffffffff) >> (32 - readSampleSize));

			x = value;
		}
		else
		{
			if (k != 1)
			{
				var extraBits : Int = readbits(alac, k);

				// x = x * (2^k - 1)
				x *= (((1 << k) - 1) & rice_kmodifier_mask);

				if (extraBits > 1)
					x += extraBits - 1;
				else
					unreadbits(alac, 1);
			}
		}

		return x;
	}

	public static function entropy_rice_decode(alac : AlacFile, outputBuffer : Array < Int >, outputSize : Int, readSampleSize : Int, rice_initialhistory : Int, rice_kmodifier : Int, rice_historymult : Int, rice_kmodifier_mask : Int) : Void
	{
		var history : Int = rice_initialhistory;
		var outputCount : Int = 0;
		var signModifier : Int = 0;

		while(outputCount < outputSize)
		{
			var decodedValue : Int = 0;
			var finalValue : Int = 0;
			var k  : Int = 0;

			k = 31 - rice_kmodifier - count_leading_zeros((history >> 9) + 3);

			if (k < 0)
				k += rice_kmodifier;
			else
				k = rice_kmodifier;

			// note: don't use rice_kmodifier_mask here (set mask to 0xFFFFFFFF)
			decodedValue = entropy_decode_value(alac, readSampleSize, k, 0xFFFFFFFF);

			decodedValue += signModifier;
			finalValue = Std.int((decodedValue + 1) / 2); // inc by 1 and shift out sign bit
			if ((decodedValue & 1) != 0) // the sign is stored in the low bit
				finalValue *= -1;

			outputBuffer[outputCount] = finalValue;

			signModifier = 0;

			// update history
			history += (decodedValue * rice_historymult) - ((history * rice_historymult) >> 9);

			if (decodedValue > 0xFFFF)
				history = 0xFFFF;

			// special case, for compressed blocks of 0
			if ((history < 128) && (outputCount + 1 < outputSize))
			{
				var blockSize : Int = 0;

				signModifier = 1;

				k = count_leading_zeros(history) + Std.int((history + 16) / 64) - 24;

				// note: blockSize is always 16bit
				blockSize = entropy_decode_value(alac, 16, k, rice_kmodifier_mask);

				// got blockSize 0s
				if (blockSize > 0)
				{
					var countSize : Int = 0;
					countSize = blockSize;
					for (j in 0 ... countSize)
					{
						outputBuffer[outputCount + 1 + j] = 0;
					}
					outputCount += blockSize;
				}

				if (blockSize > 0xFFFF)
					signModifier = 0;

				history = 0;
			}
			
			outputCount++;
		}
	}

	static function predictor_decompress_fir_adapt(error_buffer : Array < Int >, output_size : Int, readsamplesize : Int, predictor_coef_table : Array < Int >, predictor_coef_num : Int, predictor_quantitization : Int) : Array < Int >
	{
		var i : Int;
		var buffer_out_idx : Int = 0;
		var buffer_out : Array < Int > = new Array();
		var bitsmove : Int = 0;

		/* first sample always copies */
		buffer_out = error_buffer;

		if (predictor_coef_num == 0)
		{
			if (output_size <= 1)
				return(buffer_out);
			var sizeToCopy : Int = 0;
			sizeToCopy = (output_size-1) * 4;
			for (j in 0 ... sizeToCopy)
			{
				buffer_out[1 + j] = error_buffer[1 + j];
			}
			return(buffer_out);
		}

		if (predictor_coef_num == 0x1f) // 11111 - max value of predictor_coef_num
		{
		/* second-best case scenario for fir decompression,
		   * error describes a small difference from the previous sample only
		   */
			if (output_size <= 1)
				return(buffer_out);

			
			for (i in 0 ... output_size - 1)
			{
				var prev_value : Int = 0;
				var error_value : Int = 0;

				prev_value = buffer_out[i];
				error_value = error_buffer[i+1];

				bitsmove = 32 - readsamplesize;
				buffer_out[i+1] = haxe.Int32.toInt(haxe.Int32.shr(haxe.Int32.shl(haxe.Int32.ofInt(prev_value + error_value),bitsmove),bitsmove));
			}
			return(buffer_out);
		}

		/* read warm-up samples */
		if (predictor_coef_num > 0)
		{
			for (i in 0 ... predictor_coef_num)
			{
				var val : Int = 0;

				val = buffer_out[i] + error_buffer[i+1];

				bitsmove = 32 - readsamplesize;

				val = haxe.Int32.toInt(haxe.Int32.shr(haxe.Int32.shl(haxe.Int32.ofInt(val),bitsmove),bitsmove));

				buffer_out[i+1] = val;
			}
		}

		/* general case */
		if (predictor_coef_num > 0)
		{
			buffer_out_idx = 0;
			for (i in predictor_coef_num + 1 ... output_size)
			{
				var j : Int;
				var sum : Int= 0;
				var outval : Int;
				var error_val = error_buffer[i];

				for (j in 0 ... predictor_coef_num)
				{
					sum += (buffer_out[buffer_out_idx + predictor_coef_num-j] - buffer_out[buffer_out_idx]) * predictor_coef_table[j];
				}

				outval = (1 << (predictor_quantitization-1)) + sum;
				outval = outval >> predictor_quantitization;
				outval = outval + buffer_out[buffer_out_idx] + error_val;
				bitsmove = 32 - readsamplesize;

				outval = haxe.Int32.toInt(haxe.Int32.shr(haxe.Int32.shl(haxe.Int32.ofInt(outval),bitsmove),bitsmove));

				buffer_out[buffer_out_idx+predictor_coef_num+1] = outval;

				if (error_val > 0)
				{
					var predictor_num : Int = predictor_coef_num - 1;

					while (predictor_num >= 0 && error_val > 0)
					{
						var val : Int = buffer_out[buffer_out_idx] - buffer_out[buffer_out_idx + predictor_coef_num - predictor_num];
						var sign : Int = ((val < 0) ? (-1) : ((val > 0) ? (1) : (0)));

						predictor_coef_table[predictor_num] -= sign;

						val *= sign; // absolute value

						error_val -= ((val >> predictor_quantitization) * (predictor_coef_num - predictor_num));

						predictor_num--;
					}
				}
				else if (error_val < 0)
				{
					var predictor_num : Int = predictor_coef_num - 1;

					while (predictor_num >= 0 && error_val < 0)
					{
						var val : Int = buffer_out[buffer_out_idx] - buffer_out[buffer_out_idx + predictor_coef_num - predictor_num];
						var sign : Int = - ((val < 0) ? (-1) : ((val > 0) ? (1) : (0)));

						predictor_coef_table[predictor_num] -= sign;

						val *= sign; // neg value

						error_val -= ((val >> predictor_quantitization) * (predictor_coef_num - predictor_num));

						predictor_num--;
					}
				}

				buffer_out_idx++;
			}
		}
		return(buffer_out);
	}

#if flash10
	public static function deinterlace_16(buffer_a : Array < Int >, buffer_b : Array < Int >, buffer_out : flash.Vector < Int >, numchannels : Int, numsamples : Int, interlacing_shift : Int, interlacing_leftweight : Int) : Void
#else	
	public static function deinterlace_16(buffer_a : Array < Int >, buffer_b : Array < Int >, buffer_out : Array < Int >, numchannels : Int, numsamples : Int, interlacing_shift : Int, interlacing_leftweight : Int) : Void
#end	
	{
		var i : Int;
		if (numsamples <= 0)
			return;

		/* weighted interlacing */
		if (0 != interlacing_leftweight)
		{
			for (i in 0 ... numsamples)
			{
				var difference : Int = 0;
				var midright : Int = 0;
				var left : Int = 0;
				var right : Int = 0;

				midright = buffer_a[i];
				difference = buffer_b[i];

				right = (midright - ((difference * interlacing_leftweight) >> interlacing_shift));
				left = (right + difference);

				/* output is always little endian */

				buffer_out[i *numchannels] = left;
				buffer_out[i *numchannels + 1] = right;
			}

			return;
		}

		/* otherwise basic interlacing took place */
		for (i in 0 ... numsamples)
		{
			var left : Int = 0;
			var right : Int = 0;

			left = buffer_a[i];
			right = buffer_b[i];

			/* output is always little endian */

			buffer_out[i *numchannels] = left;
			buffer_out[i *numchannels + 1] = right;
		}
	}

#if flash10
	public static function deinterlace_24(buffer_a : Array < Int >, buffer_b : Array < Int >, uncompressed_bytes : Int, uncompressed_bytes_buffer_a : Array < Int >, uncompressed_bytes_buffer_b : Array < Int >, buffer_out : flash.Vector < Int >, numchannels : Int, numsamples : Int, interlacing_shift : Int, interlacing_leftweight : Int) : Void
#else 
	public static function deinterlace_24(buffer_a : Array < Int >, buffer_b : Array < Int >, uncompressed_bytes : Int, uncompressed_bytes_buffer_a : Array < Int >, uncompressed_bytes_buffer_b : Array < Int >, buffer_out : Array < Int >, numchannels : Int, numsamples : Int, interlacing_shift : Int, interlacing_leftweight : Int) : Void
#end	
	{
		var i : Int;
		if (numsamples <= 0)
			return;

		/* weighted interlacing */
		if (interlacing_leftweight != 0)
		{
			for (i in 0 ... numsamples)
			{
				var difference : Int = 0;
				var midright : Int = 0;
				var left : Int = 0;
				var right : Int = 0;

				midright = buffer_a[i];
				difference = buffer_b[i];

				right = midright - ((difference * interlacing_leftweight) >> interlacing_shift);
				left = right + difference;

				if (uncompressed_bytes != 0)
				{
					var mask : Int = haxe.Int32.toInt(haxe.Int32.complement(haxe.Int32.ofInt((0xFFFFFFFF << (uncompressed_bytes * 8)))));
					left <<= (uncompressed_bytes * 8);
					right <<= (uncompressed_bytes * 8);

					left = left | (uncompressed_bytes_buffer_a[i] & mask);
					right = right | (uncompressed_bytes_buffer_b[i] & mask);
				}

				buffer_out[i * numchannels * 3] = (left & 0xFF);
				buffer_out[i * numchannels * 3 + 1] = ((left >> 8) & 0xFF);
				buffer_out[i * numchannels * 3 + 2] = ((left >> 16) & 0xFF);

				buffer_out[i * numchannels * 3 + 3] = (right & 0xFF);
				buffer_out[i * numchannels * 3 + 4] = ((right >> 8) & 0xFF);
				buffer_out[i * numchannels * 3 + 5] = ((right >> 16) & 0xFF);
			}

			return;
		}

		/* otherwise basic interlacing took place */
		for (i in 0 ... numsamples)
		{
			var left : Int = 0;
			var right : Int = 0;

			left = buffer_a[i];
			right = buffer_b[i];

			if (uncompressed_bytes != 0)
			{
				var mask : Int = haxe.Int32.toInt(haxe.Int32.complement(haxe.Int32.ofInt((0xFFFFFFFF << (uncompressed_bytes * 8)))));
				left <<= (uncompressed_bytes * 8);
				right <<= (uncompressed_bytes * 8);

				left = left | (uncompressed_bytes_buffer_a[i] & mask);
				right = right | (uncompressed_bytes_buffer_b[i] & mask);
			}

			buffer_out[i * numchannels * 3] = (left & 0xFF);
			buffer_out[i * numchannels * 3 + 1] = ((left >> 8) & 0xFF);
			buffer_out[i * numchannels * 3 + 2] = ((left >> 16) & 0xFF);

			buffer_out[i * numchannels * 3 + 3] = (right & 0xFF);
			buffer_out[i * numchannels * 3 + 4] = ((right >> 8) & 0xFF);
			buffer_out[i * numchannels * 3 + 5] = ((right >> 16) & 0xFF);

		}

	}

#if flash10
	public static function decode_frame(alac : AlacFile, inbuffer : flash.Vector < Int >, outbuffer : flash.Vector < Int >, outputsize : Int) : Int
#else	
	public static function decode_frame(alac : AlacFile, inbuffer : Array < Int >, outbuffer : Array < Int >, outputsize : Int) : Int
#end	
	{
		var channels : Int;
		var outputsamples : Int = alac.setinfo_max_samples_per_frame;

		/* setup the stream */
		alac.input_buffer = inbuffer;
		alac.input_buffer_bitaccumulator = 0;
		alac.ibIdx = 0;


		channels = readbits(alac, 3);

		outputsize = outputsamples * alac.bytespersample;

		if(channels == 0) // 1 channel
		{
			var hassize : Int;
			var isnotcompressed : Int;
			var readsamplesize : Int;

			var uncompressed_bytes : Int;
			var ricemodifier : Int;
	
			var tempPred : Int = 0;

			/* 2^result = something to do with output waiting.
			 * perhaps matters if we read > 1 frame in a pass?
			 */
			readbits(alac, 4);

			readbits(alac, 12); // unknown, skip 12 bits

			hassize = readbits(alac, 1); // the output sample size is stored soon

			uncompressed_bytes = readbits(alac, 2); // number of bytes in the (compressed) stream that are not compressed

			isnotcompressed = readbits(alac, 1); // whether the frame is compressed

			if (hassize != 0)
			{
				/* now read the number of samples,
				 * as a 32bit integer */
				outputsamples = readbits(alac, 32);
				outputsize = outputsamples * alac.bytespersample;
			}

			readsamplesize = alac.setinfo_sample_size - (uncompressed_bytes * 8);

			if (isnotcompressed == 0)
			{ // so it is compressed
				var predictor_coef_table : Array < Int > = new Array();
				var predictor_coef_num : Int;
				var prediction_type : Int;
				var prediction_quantitization : Int;
				var i : Int;

				/* skip 16 bits, not sure what they are. seem to be used in
				 * two channel case */
				readbits(alac, 8);
				readbits(alac, 8);

				prediction_type = readbits(alac, 4);
				prediction_quantitization = readbits(alac, 4);

				ricemodifier = readbits(alac, 3);
				predictor_coef_num = readbits(alac, 5);

				/* read the predictor table */
				for (i in 0 ... predictor_coef_num)
				{
					tempPred = readbits(alac,16);
					if(tempPred > 32767)
					{
						// the predictor coef table values are only 16 bit signed
						tempPred = tempPred - 65536;
					}

					predictor_coef_table[i] = tempPred;
				}

				if (uncompressed_bytes != 0)
				{
					for (i in 0 ... outputsamples)
					{
						alac.uncompressed_bytes_buffer_a[i] = readbits(alac, uncompressed_bytes * 8);
					}
				}
				
				entropy_rice_decode(alac, alac.predicterror_buffer_a, outputsamples, readsamplesize, alac.setinfo_rice_initialhistory, alac.setinfo_rice_kmodifier, ricemodifier * Std.int(alac.setinfo_rice_historymult / 4), (1 << alac.setinfo_rice_kmodifier) - 1);

				if (prediction_type == 0)
				{ // adaptive fir
					alac.outputsamples_buffer_a = predictor_decompress_fir_adapt(alac.predicterror_buffer_a, outputsamples, readsamplesize, predictor_coef_table, predictor_coef_num, prediction_quantitization);
				}
				else
				{
					trace("FIXME: unhandled predicition type: " +prediction_type);
					
					/* i think the only other prediction type (or perhaps this is just a
					 * boolean?) runs adaptive fir twice.. like:
					 * predictor_decompress_fir_adapt(predictor_error, tempout, ...)
					 * predictor_decompress_fir_adapt(predictor_error, outputsamples ...)
					 * little strange..
					 */
				}

			}
			else
			{ // not compressed, easy case
				if (alac.setinfo_sample_size <= 16)
				{
					var i : Int;
					var bitsmove : Int = 0;
					for (i in 0 ... outputsamples)
					{
						var audiobits : Int = readbits(alac, alac.setinfo_sample_size);
						bitsmove = 32 - alac.setinfo_sample_size;

						audiobits = haxe.Int32.toInt(haxe.Int32.shr(haxe.Int32.shl(haxe.Int32.ofInt(audiobits),bitsmove),bitsmove));

						alac.outputsamples_buffer_a[i] = audiobits;
					}
				}
				else
				{
					var i : Int;
					var x : Int;
					var m : Int = 1 << (24 -1);
					for (i in 0 ... outputsamples)
					{
						var audiobits : Int;

						audiobits = readbits(alac, 16);
						/* special case of sign extension..
						 * as we'll be ORing the low 16bits into this */
						audiobits = audiobits << (alac.setinfo_sample_size - 16);
						audiobits = audiobits | readbits(alac, alac.setinfo_sample_size - 16);
						x = audiobits & ((1 << 24) - 1);
						audiobits = (x ^ m) - m;	// sign extend 24 bits
						
						alac.outputsamples_buffer_a[i] = audiobits;
					}
				}
				uncompressed_bytes = 0; // always 0 for uncompressed
			}

			switch(alac.setinfo_sample_size)
			{
			case 16:
			{
				var i : Int;

				for (i in 0 ... outputsamples)
				{
					var sample : Int = alac.outputsamples_buffer_a[i];
					outbuffer[i * alac.numchannels] = sample;
									
					/*
					** We have to handle the case where the data is actually mono, but the stsd atom says it has 2 channels
					** in this case we create a stereo file where one of the channels is silent. If mono and 1 channel this value 
					** will be overwritten in the next iteration
					*/
					
					outbuffer[(i * alac.numchannels) + 1] = 0;
				}
			}
			case 24:
			{
				var i : Int;
				for (i in 0 ... outputsamples)
				{
					var sample : Int = alac.outputsamples_buffer_a[i];

					if (uncompressed_bytes != 0)
					{
						var mask : Int = 0;
						sample = sample << (uncompressed_bytes * 8);
						mask = haxe.Int32.toInt(haxe.Int32.complement(haxe.Int32.ofInt((0xFFFFFFFF << (uncompressed_bytes * 8)))));
						sample = sample | (alac.uncompressed_bytes_buffer_a[i] & mask);
					}

					outbuffer[i * alac.numchannels * 3] = ((sample) & 0xFF);
					outbuffer[i * alac.numchannels * 3 + 1] = ((sample >> 8) & 0xFF);
					outbuffer[i * alac.numchannels * 3 + 2] = ((sample >> 16) & 0xFF);
					
					/*
					** We have to handle the case where the data is actually mono, but the stsd atom says it has 2 channels
					** in this case we create a stereo file where one of the channels is silent. If mono and 1 channel this value 
					** will be overwritten in the next iteration
					*/
					
					outbuffer[i * alac.numchannels * 3 + 3] = 0;
					outbuffer[i * alac.numchannels * 3 + 4] = 0;
					outbuffer[i * alac.numchannels * 3 + 5] = 0;
					
				}
			}
			case 20:
			case 32:
				trace("FIXME: unimplemented sample size " + alac.setinfo_sample_size);
			default:

			}
		}
		else if(channels == 1) // 2 channels
		{
			var hassize : Int;
			var isnotcompressed : Int;
			var readsamplesize : Int;

			var uncompressed_bytes : Int;

			var interlacing_shift : Int;
			var interlacing_leftweight : Int;

			/* 2^result = something to do with output waiting.
			 * perhaps matters if we read > 1 frame in a pass?
			 */
			readbits(alac, 4);

			readbits(alac, 12); // unknown, skip 12 bits

			hassize = readbits(alac, 1); // the output sample size is stored soon

			uncompressed_bytes = readbits(alac, 2); // the number of bytes in the (compressed) stream that are not compressed

			isnotcompressed = readbits(alac, 1); // whether the frame is compressed

			if (hassize != 0)
			{
				/* now read the number of samples,
				 * as a 32bit integer */
				outputsamples = readbits(alac, 32);
				outputsize = outputsamples * alac.bytespersample;
			}

			readsamplesize = alac.setinfo_sample_size - (uncompressed_bytes * 8) + 1;

			if (isnotcompressed == 0)
			{ // compressed
				var predictor_coef_table_a : Array < Int > = new Array();
				var predictor_coef_num_a : Int;
				var prediction_type_a : Int;
				var prediction_quantitization_a : Int;
				var ricemodifier_a : Int;

				var predictor_coef_table_b : Array < Int > = new Array();
				var predictor_coef_num_b : Int;
				var prediction_type_b : Int;
				var prediction_quantitization_b : Int;
				var ricemodifier_b : Int;

				var i : Int;
				var tempPred : Int = 0;

				interlacing_shift = readbits(alac, 8);
				interlacing_leftweight = readbits(alac, 8);

				/******** channel 1 ***********/
				prediction_type_a = readbits(alac, 4);
				prediction_quantitization_a = readbits(alac, 4);

				ricemodifier_a = readbits(alac, 3);
				predictor_coef_num_a = readbits(alac, 5);

				/* read the predictor table */
				for (i in 0 ... predictor_coef_num_a)
				{
					tempPred = readbits(alac,16);
					if(tempPred > 32767)
					{
						// the predictor coef table values are only 16 bit signed
						tempPred = tempPred - 65536;
					}
					predictor_coef_table_a[i] = tempPred;
				}

				/******** channel 2 *********/
				prediction_type_b = readbits(alac, 4);
				prediction_quantitization_b = readbits(alac, 4);

				ricemodifier_b = readbits(alac, 3);
				predictor_coef_num_b = readbits(alac, 5);

				/* read the predictor table */
				for (i in 0 ... predictor_coef_num_b)
				{
					tempPred = readbits(alac,16);
					if(tempPred > 32767)
					{
						// the predictor coef table values are only 16 bit signed
						tempPred = tempPred - 65536;
					}
					predictor_coef_table_b[i] = tempPred;
				}

				/*********************/
				if (uncompressed_bytes != 0)
				{ // see mono case
					for (i in 0 ... outputsamples)
					{
						alac.uncompressed_bytes_buffer_a[i] = readbits(alac, uncompressed_bytes * 8);
						alac.uncompressed_bytes_buffer_b[i] = readbits(alac, uncompressed_bytes * 8);
					}
				}

				/* channel 1 */

				entropy_rice_decode(alac, alac.predicterror_buffer_a, outputsamples, readsamplesize, alac.setinfo_rice_initialhistory, alac.setinfo_rice_kmodifier, ricemodifier_a * Std.int(alac.setinfo_rice_historymult / 4), (1 << alac.setinfo_rice_kmodifier) - 1);

				if (prediction_type_a == 0)
				{ // adaptive fir

					alac.outputsamples_buffer_a = predictor_decompress_fir_adapt(alac.predicterror_buffer_a, outputsamples, readsamplesize, predictor_coef_table_a, predictor_coef_num_a, prediction_quantitization_a);

				}
				else
				{ // see mono case
					trace("FIXME: unhandled predicition type: " + prediction_type_a);
				}

				/* channel 2 */
				entropy_rice_decode(alac, alac.predicterror_buffer_b, outputsamples, readsamplesize, alac.setinfo_rice_initialhistory, alac.setinfo_rice_kmodifier, ricemodifier_b * Std.int(alac.setinfo_rice_historymult / 4), (1 << alac.setinfo_rice_kmodifier) - 1);

				if (prediction_type_b == 0)
				{ // adaptive fir
					alac.outputsamples_buffer_b = predictor_decompress_fir_adapt(alac.predicterror_buffer_b, outputsamples, readsamplesize, predictor_coef_table_b, predictor_coef_num_b, prediction_quantitization_b);
				}
				else
				{
					trace("FIXME: unhandled predicition type: " + prediction_type_b);
				}
			}
			else
			{ // not compressed, easy case
				if (alac.setinfo_sample_size <= 16)
				{
					var i : Int;
					var bitsmove : Int;
					
					for (i in 0 ... outputsamples)
					{
						var audiobits_a : Int;
						var audiobits_b : Int;

						audiobits_a = readbits(alac, alac.setinfo_sample_size);
						audiobits_b = readbits(alac, alac.setinfo_sample_size);
						
						bitsmove = 32 - alac.setinfo_sample_size;

						audiobits_a = haxe.Int32.toInt(haxe.Int32.shr(haxe.Int32.shl(haxe.Int32.ofInt(audiobits_a),bitsmove),bitsmove));
						audiobits_b = haxe.Int32.toInt(haxe.Int32.shr(haxe.Int32.shl(haxe.Int32.ofInt(audiobits_b),bitsmove),bitsmove));

						alac.outputsamples_buffer_a[i] = audiobits_a;
						alac.outputsamples_buffer_b[i] = audiobits_b;
					}
				}
				else
				{
					var i : Int;
					var x : Int;
					var m : Int = 1 << (24 -1);

					for (i in 0 ... outputsamples)
					{
						var audiobits_a : Int;
						var audiobits_b : Int;

						audiobits_a = readbits(alac, 16);
						audiobits_a = audiobits_a << (alac.setinfo_sample_size - 16);
						audiobits_a = audiobits_a | readbits(alac, alac.setinfo_sample_size - 16);
						x = audiobits_a & ((1 << 24) - 1);
						audiobits_a = (x ^ m) - m;        // sign extend 24 bits

						audiobits_b = readbits(alac, 16);
						audiobits_b = audiobits_b << (alac.setinfo_sample_size - 16);
						audiobits_b = audiobits_b | readbits(alac, alac.setinfo_sample_size - 16);
						x = audiobits_b & ((1 << 24) - 1);
						audiobits_b = (x ^ m) - m;        // sign extend 24 bits

						alac.outputsamples_buffer_a[i] = audiobits_a;
						alac.outputsamples_buffer_b[i] = audiobits_b;
					}
				}
				uncompressed_bytes = 0; // always 0 for uncompressed
				interlacing_shift = 0;
				interlacing_leftweight = 0;
			}

			switch(alac.setinfo_sample_size)
			{
			case 16:
			{
				deinterlace_16(alac.outputsamples_buffer_a, alac.outputsamples_buffer_b, outbuffer, alac.numchannels, outputsamples, interlacing_shift, interlacing_leftweight);
			}
			case 24:
			{
				deinterlace_24(alac.outputsamples_buffer_a, alac.outputsamples_buffer_b, uncompressed_bytes, alac.uncompressed_bytes_buffer_a, alac.uncompressed_bytes_buffer_b, outbuffer, alac.numchannels, outputsamples, interlacing_shift, interlacing_leftweight);
			}
			case 20:
			case 32:
				trace("FIXME: unimplemented sample size " + alac.setinfo_sample_size);

			default:

			}
		}
		return outputsize;
	}

	public static function create_alac(samplesize : Int, numchannels : Int) : AlacFile
	{
		var newfile : AlacFile = new AlacFile();

		newfile.samplesize = samplesize;
		newfile.numchannels = numchannels;
		newfile.bytespersample = Std.int(samplesize / 8) * numchannels;

		return newfile;
	}
}

