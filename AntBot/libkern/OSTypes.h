<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<!-- saved from url=(0082)http://www.opensource.apple.com/source/xnu/xnu-1456.1.26/libkern/libkern/OSTypes.h -->
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en"><head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<title>OSTypes.h</title>
<style type="text/css">
.enscript-comment { font-style: italic; color: rgb(178,34,34); }
.enscript-function-name { font-weight: bold; color: rgb(0,0,255); }
.enscript-variable-name { font-weight: bold; color: rgb(184,134,11); }
.enscript-keyword { font-weight: bold; color: rgb(160,32,240); }
.enscript-reference { font-weight: bold; color: rgb(95,158,160); }
.enscript-string { font-weight: bold; color: rgb(188,143,143); }
.enscript-builtin { font-weight: bold; color: rgb(218,112,214); }
.enscript-type { font-weight: bold; color: rgb(34,139,34); }
.enscript-highlight { text-decoration: underline; color: 0; }
</style>
</head>
<body id="top">
<h1 style="margin:8px;" id="f1">OSTypes.h&nbsp;&nbsp;&nbsp;<span style="font-weight: normal; font-size: 0.5em;">[<a href="http://www.opensource.apple.com/source/xnu/xnu-1456.1.26/libkern/libkern/OSTypes.h?txt">plain text</a>]</span></h1>
<hr>
<div></div>
<pre><span class="enscript-comment">/*
 * Copyright (c) 2000 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 * 
 * Please obtain a copy of the License at
 * <a href="http://www.opensource.apple.com/apsl/">http://www.opensource.apple.com/apsl/</a> and read it before using this file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */</span>
<span class="enscript-comment">/*
 * Copyright (c) 1999 Apple Computer, Inc.  All rights reserved.
 *
 * HISTORY
 *
 */</span>

#<span class="enscript-reference">ifndef</span> <span class="enscript-variable-name">_OS_OSTYPES_H</span>
#<span class="enscript-reference">define</span> <span class="enscript-variable-name">_OS_OSTYPES_H</span>

#<span class="enscript-reference">define</span> <span class="enscript-variable-name">OSTYPES_K64_REV</span>		2

<span class="enscript-type">typedef</span> <span class="enscript-type">unsigned</span> <span class="enscript-type">int</span> 	   UInt;
<span class="enscript-type">typedef</span> <span class="enscript-type">signed</span> <span class="enscript-type">int</span>         SInt;

#<span class="enscript-reference">ifndef</span> <span class="enscript-variable-name">__MACTYPES__</span>	<span class="enscript-comment">/* CF MacTypes.h */</span>
#<span class="enscript-reference">ifndef</span> <span class="enscript-variable-name">__TYPES__</span>	<span class="enscript-comment">/* guess... Mac Types.h */</span>

<span class="enscript-type">typedef</span> <span class="enscript-type">unsigned</span> <span class="enscript-type">char</span> 	   UInt8;
<span class="enscript-type">typedef</span> <span class="enscript-type">unsigned</span> <span class="enscript-type">short</span> 	   UInt16;
#<span class="enscript-reference">if</span> <span class="enscript-variable-name">__LP64__</span>
<span class="enscript-type">typedef</span> <span class="enscript-type">unsigned</span> <span class="enscript-type">int</span>       UInt32;
#<span class="enscript-reference">else</span>
<span class="enscript-type">typedef</span> <span class="enscript-type">unsigned</span> <span class="enscript-type">long</span>      UInt32;
#<span class="enscript-reference">endif</span>
<span class="enscript-type">typedef</span> <span class="enscript-type">unsigned</span> <span class="enscript-type">long</span> <span class="enscript-type">long</span> UInt64;
#<span class="enscript-reference">if</span>		<span class="enscript-reference">defined</span>(<span class="enscript-variable-name">__BIG_ENDIAN__</span>)
<span class="enscript-type">typedef</span>	<span class="enscript-type">struct</span> UnsignedWide {
			UInt32		hi;
			UInt32		lo;
}							UnsignedWide;
#<span class="enscript-reference">elif</span>		<span class="enscript-reference">defined</span>(<span class="enscript-variable-name">__LITTLE_ENDIAN__</span>)
<span class="enscript-type">typedef</span>	<span class="enscript-type">struct</span> UnsignedWide {
			UInt32		lo;
			UInt32		hi;
}							UnsignedWide;
#<span class="enscript-reference">else</span>
#<span class="enscript-reference">error</span> <span class="enscript-variable-name">Unknown</span> <span class="enscript-variable-name">endianess</span>.
#<span class="enscript-reference">endif</span>

<span class="enscript-type">typedef</span> <span class="enscript-type">signed</span> <span class="enscript-type">char</span> 	   SInt8;
<span class="enscript-type">typedef</span> <span class="enscript-type">signed</span> <span class="enscript-type">short</span> 	   SInt16;
#<span class="enscript-reference">if</span> <span class="enscript-variable-name">__LP64__</span>
<span class="enscript-type">typedef</span> <span class="enscript-type">signed</span> <span class="enscript-type">int</span>         SInt32;
#<span class="enscript-reference">else</span>
<span class="enscript-type">typedef</span> <span class="enscript-type">signed</span> <span class="enscript-type">long</span>        SInt32;
#<span class="enscript-reference">endif</span>
<span class="enscript-type">typedef</span> <span class="enscript-type">signed</span> <span class="enscript-type">long</span> <span class="enscript-type">long</span>   SInt64;
#<span class="enscript-reference">if</span>		<span class="enscript-reference">defined</span>(<span class="enscript-variable-name">__BIG_ENDIAN__</span>)
<span class="enscript-type">typedef</span>	<span class="enscript-type">struct</span> wide {
			SInt32		hi;
			UInt32		lo;
}							wide;
#<span class="enscript-reference">elif</span>		<span class="enscript-reference">defined</span>(<span class="enscript-variable-name">__LITTLE_ENDIAN__</span>)
<span class="enscript-type">typedef</span>	<span class="enscript-type">struct</span> wide {
			UInt32		lo;
			SInt32		hi;
}							wide;
#<span class="enscript-reference">else</span>
#<span class="enscript-reference">error</span> <span class="enscript-variable-name">Unknown</span> <span class="enscript-variable-name">endianess</span>.
#<span class="enscript-reference">endif</span>

<span class="enscript-type">typedef</span> SInt32				OSStatus;

#<span class="enscript-reference">if</span> <span class="enscript-reference">defined</span>(<span class="enscript-variable-name">__LP64__</span>) &amp;&amp; <span class="enscript-reference">defined</span>(<span class="enscript-variable-name">KERNEL</span>)
#<span class="enscript-reference">ifndef</span> <span class="enscript-variable-name">ABSOLUTETIME_SCALAR_TYPE</span>
#<span class="enscript-reference">define</span> <span class="enscript-variable-name">ABSOLUTETIME_SCALAR_TYPE</span>    1
#<span class="enscript-reference">endif</span>
<span class="enscript-type">typedef</span> UInt64		AbsoluteTime;
#<span class="enscript-reference">else</span>
<span class="enscript-type">typedef</span> UnsignedWide		AbsoluteTime;
#<span class="enscript-reference">endif</span>

<span class="enscript-type">typedef</span> UInt32				OptionBits;

#<span class="enscript-reference">if</span> <span class="enscript-reference">defined</span>(<span class="enscript-variable-name">KERNEL</span>) &amp;&amp; <span class="enscript-reference">defined</span>(<span class="enscript-variable-name">__LP64__</span>)
<span class="enscript-comment">/*
 * Use intrinsic boolean types for the LP64 kernel, otherwise maintain
 * source and binary backward compatibility.  This attempts to resolve
 * the "(x == true)" vs. "(x)" conditional issue.
 */</span>
#<span class="enscript-reference">ifdef</span> <span class="enscript-variable-name">__cplusplus</span>
<span class="enscript-type">typedef</span> bool Boolean;
#<span class="enscript-reference">else</span>	<span class="enscript-comment">/* !__cplusplus */</span>
#<span class="enscript-reference">if</span> <span class="enscript-reference">defined</span>(<span class="enscript-variable-name">__STDC_VERSION__</span>) &amp;&amp; ((<span class="enscript-variable-name">__STDC_VERSION__</span> - 199901L) &gt; 0L)
<span class="enscript-comment">/* only use this if we are sure we are using a c99 compiler */</span>
<span class="enscript-type">typedef</span> _Bool Boolean;
#<span class="enscript-reference">else</span>	<span class="enscript-comment">/* !c99 */</span>
<span class="enscript-comment">/* Fall back to previous definition unless c99 */</span>
<span class="enscript-type">typedef</span> <span class="enscript-type">unsigned</span> <span class="enscript-type">char</span> Boolean;
#<span class="enscript-reference">endif</span>	<span class="enscript-comment">/* !c99 */</span>
#<span class="enscript-reference">endif</span>	<span class="enscript-comment">/* !__cplusplus */</span>
#<span class="enscript-reference">else</span>	<span class="enscript-comment">/* !(KERNEL &amp;&amp; __LP64__) */</span>
<span class="enscript-type">typedef</span> <span class="enscript-type">unsigned</span> <span class="enscript-type">char</span> Boolean;
#<span class="enscript-reference">endif</span>	<span class="enscript-comment">/* !(KERNEL &amp;&amp; __LP64__) */</span>

#<span class="enscript-reference">endif</span> <span class="enscript-comment">/* __TYPES__ */</span>
#<span class="enscript-reference">endif</span> <span class="enscript-comment">/* __MACTYPES__ */</span>

#<span class="enscript-reference">if</span> !<span class="enscript-reference">defined</span>(<span class="enscript-variable-name">OS_INLINE</span>)
#	<span class="enscript-reference">define</span> <span class="enscript-variable-name">OS_INLINE</span> static inline
#<span class="enscript-reference">endif</span>

#<span class="enscript-reference">endif</span> <span class="enscript-comment">/* _OS_OSTYPES_H */</span>
</pre>
<hr>
</body></html>