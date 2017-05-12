/*
 * This file was generated automatically by ExtUtils::ParseXS version 3.28 from the
 * contents of OpenCV.xs. Do not edit this file, edit OpenCV.xs instead.
 *
 *    ANY CHANGES MADE HERE WILL BE LOST!
 *
 */

#line 1 "lib/GoatKCD/Extractor/OpenCV.xs"
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#undef seed

#include <opencv/cv.h>
#include <opencv/highgui.h>
#include <opencv2/highgui/highgui_c.h>
#include <opencv2/imgproc/imgproc_c.h>
#include <math.h>
#include <stdio.h>

#define MORPH_ELLIPSE   2
#define MORPH_GRADIENT  4
#define MORPH_RECT  0
#define MORPH_CLOSE 3
#define THRESH_BINARY 0
#define THRESH_OTSU 8
#define SHRINK_BY  10
#define COMPLEXITY 1


/*
void draw_lines_prob(IplImage* img,IplImage* color_img, CvSeq* lines) {
    lines = cvHoughLines2( img, cvCreateMemStorage(0), CV_HOUGH_PROBABILISTIC, 1, (CV_PI/180), 50, 50, 10 );
    for(int i = 0; i<lines->total; i++ ) {
        CvPoint* line = (CvPoint*)cvGetSeqElem(lines,i);
        if (abs(line[0].x-line[1].x) || abs(line[0].y-line[1].y)<=5) {
            cvLine( color_img, line[0], line[1], CV_RGB(0,0,0xff), 1, CV_AA, 0 );
        }
    }
}
void showImage(IplImage* img,const char* title) {
    cvNamedWindow( title, 1 );
    cvShowImage( title, img );
    cvWaitKey(0);
}

void draw_lines_standard(IplImage* img,IplImage* color_img,CvSeq* lines) {
    lines = cvHoughLines2( img, cvCreateMemStorage(0), CV_HOUGH_STANDARD, 1, CV_PI/180, 50, 50, 10 );
    for(int i = 0; i < MIN(lines->total,300); i++ ) {
        float* line = (float*)cvGetSeqElem(lines,i);
        float rho = line[0];
        float theta = line[1];
        CvPoint pt1;
        CvPoint pt2;
        double a = cos(theta), b = sin(theta);
        double x0 = a*rho, y0 = b*rho;
        pt1.x = cvRound(x0 + 1000*(-b));
        pt1.y = cvRound(y0 + 1000*(a));
        pt2.x = cvRound(x0 - 1000*(-b));
        pt2.y = cvRound(y0 - 1000*(a));
        if (abs(pt2.x-pt1.x)<=5 || abs(pt1.y-pt2.y)<=5) {
            cvLine( color_img, pt1, pt2, CV_RGB(0,0xff,0x00), 1, CV_AA, 0 );
        }
    }
}
*/

SV* process_lines(IplImage* orig,int x,int y,int width, int height) {

	SV* retval = newSV(0);
	if( !orig ) {
        return retval;
    }
	//CvSize size = cvGetSize(orig);
	IplImage* src;// = cvLoadImage( filename, 0 );
    if (width<1 && height<1) {
		src = cvCloneImage(orig);
	} else {
		cvSetImageROI(orig,cvRect(x,y,width,height));
		src = cvCreateImage(cvGetSize(orig),8,1);
		cvCopy(orig,src,NULL);
		cvResetImageROI(orig);
	}
    int i;

	CvSize size = cvGetSize(src);

	/* Detect and eliminate text and complex shapes */

    IplImage* morph = cvCloneImage(src);
    IplImage* grad = cvCreateImage(size, 8, 1 );
    IplImage* bw = cvCreateImage(size, 8, 1 );
	CvMemStorage* storage = cvCreateMemStorage(0);

    IplConvKernel* kernel = cvCreateStructuringElementEx(3,3,0,0,MORPH_ELLIPSE,NULL);
    cvMorphologyEx(morph,grad,storage,kernel,MORPH_GRADIENT,1);
    cvThreshold(grad,bw,0.0,255.0, THRESH_BINARY | THRESH_OTSU);

	IplImage* gray = cvCreateImage(size, 8, 1 );
	cvCanny( src, gray, 20, 200, 3 );

    CvSeq *contours = cvCreateSeq(0, sizeof(CvSeq), sizeof(CvPoint), storage);
	cvClearMemStorage(storage);
    int count = cvFindContours(bw, storage, &contours, sizeof(CvContour), CV_RETR_LIST,CV_CHAIN_APPROX_SIMPLE, cvPoint(0,0));

    if (1) {
        for(; contours!=0; contours = contours->h_next) {
        	CvRect rect = cvBoundingRect(contours,0);
				/* delete detected shapes from outlines to reduce noise. */
            cvRectangle(gray,cvPoint(rect.x+SHRINK_BY,rect.y+SHRINK_BY),cvPoint(rect.x+rect.width-SHRINK_BY,rect.y+rect.height-SHRINK_BY),CV_RGB(0,0,0),-1,8,0);
			cvRectangle(gray,cvPoint(rect.x+SHRINK_BY,rect.y+SHRINK_BY),cvPoint(rect.x+rect.width-SHRINK_BY,rect.y+rect.height-SHRINK_BY),CV_RGB(0,0,0),2,8,0);
        }
    }




	HV* data = newHV();
	AV* slines = newAV();
	cvClearMemStorage(storage);
    CvSeq* lines = cvHoughLines2( gray, storage, CV_HOUGH_STANDARD, 1, CV_PI/180, 50, 50, 10 );
    for(int i = 0; i < MIN(lines->total,100); i++ ) {
        float* line = (float*)cvGetSeqElem(lines,i);
        float rho = line[0];
        float theta = line[1];
        CvPoint pt1;
        CvPoint pt2;
        double a = cos(theta), b = sin(theta);
        double x0 = a*rho, y0 = b*rho;
        pt1.x = cvRound(x0 + 1000*(-b));
        pt1.y = cvRound(y0 + 1000*(a));
        pt2.x = cvRound(x0 - 1000*(-b));
        pt2.y = cvRound(y0 - 1000*(a));
		//if (pt1.y>pt2.y) { pt1.y = pt2.y; } else { pt2.y = pt1.y; }
        if (abs(pt2.x-pt1.x)<=5 || abs(pt1.y-pt2.y)<=5) {

			AV* ltt;
            ltt  = newAV();
			av_push(ltt,newSViv(pt1.x));
            av_push(ltt,newSViv(pt1.y));
			av_push(ltt,newSViv(pt2.x));
            av_push(ltt,newSViv(pt2.y));
			av_push(slines,newRV((SV*)ltt));

        }
		
	}

	hv_store(data,"lines",5,newRV((SV*)slines),0);
	cvClearMemStorage(lines->storage);
	cvClearMemStorage(storage);

	lines = cvHoughLines2( gray, storage, CV_HOUGH_PROBABILISTIC, 1, (CV_PI/180), 50, 50, 10 );

	AV* plines = newAV();
    for(int i = 0; i<lines->total; i++ ) {
        CvPoint* line = (CvPoint*)cvGetSeqElem(lines,i);
        if (abs(line[0].y-line[1].y)<=5) {
			if (line[0].y>line[1].y) { line[0].y = line[1].y; } else { line[1].y = line[0].y; }
			AV* ltt;
			ltt  = newAV();
            av_push(ltt,newSViv(line[0].y));
			av_push(ltt,newSViv(abs(line[1].x-line[0].x)));
			av_push(plines,newRV((SV*)ltt));
        }
    }
	cvClearMemStorage(lines->storage);

	cvReleaseImage(&src);
	cvReleaseImage(&gray);
	cvReleaseImage(&morph);
	cvReleaseImage(&bw);
	cvReleaseImage(&src);
	cvReleaseMemStorage(&storage);
	cvReleaseStructuringElement(&kernel);
	cvReleaseMemStorage(&contours);


	hv_store(data,"checklines",10,newRV((SV*)plines),0);
	return newRV((SV*)data);
}

IplImage* load_image(const char* filename) {
	IplImage* src = cvLoadImage( filename, 0 );
	return src;
}
void release_image(IplImage* img) {
	if (!img) {
		return;
	}
	cvReleaseImage(&img);
}
	


#line 198 "lib/GoatKCD/Extractor/OpenCV.c"
#ifndef PERL_UNUSED_VAR
#  define PERL_UNUSED_VAR(var) if (0) var = var
#endif

#ifndef dVAR
#  define dVAR		dNOOP
#endif


/* This stuff is not part of the API! You have been warned. */
#ifndef PERL_VERSION_DECIMAL
#  define PERL_VERSION_DECIMAL(r,v,s) (r*1000000 + v*1000 + s)
#endif
#ifndef PERL_DECIMAL_VERSION
#  define PERL_DECIMAL_VERSION \
	  PERL_VERSION_DECIMAL(PERL_REVISION,PERL_VERSION,PERL_SUBVERSION)
#endif
#ifndef PERL_VERSION_GE
#  define PERL_VERSION_GE(r,v,s) \
	  (PERL_DECIMAL_VERSION >= PERL_VERSION_DECIMAL(r,v,s))
#endif
#ifndef PERL_VERSION_LE
#  define PERL_VERSION_LE(r,v,s) \
	  (PERL_DECIMAL_VERSION <= PERL_VERSION_DECIMAL(r,v,s))
#endif

/* XS_INTERNAL is the explicit static-linkage variant of the default
 * XS macro.
 *
 * XS_EXTERNAL is the same as XS_INTERNAL except it does not include
 * "STATIC", ie. it exports XSUB symbols. You probably don't want that
 * for anything but the BOOT XSUB.
 *
 * See XSUB.h in core!
 */


/* TODO: This might be compatible further back than 5.10.0. */
#if PERL_VERSION_GE(5, 10, 0) && PERL_VERSION_LE(5, 15, 1)
#  undef XS_EXTERNAL
#  undef XS_INTERNAL
#  if defined(__CYGWIN__) && defined(USE_DYNAMIC_LOADING)
#    define XS_EXTERNAL(name) __declspec(dllexport) XSPROTO(name)
#    define XS_INTERNAL(name) STATIC XSPROTO(name)
#  endif
#  if defined(__SYMBIAN32__)
#    define XS_EXTERNAL(name) EXPORT_C XSPROTO(name)
#    define XS_INTERNAL(name) EXPORT_C STATIC XSPROTO(name)
#  endif
#  ifndef XS_EXTERNAL
#    if defined(HASATTRIBUTE_UNUSED) && !defined(__cplusplus)
#      define XS_EXTERNAL(name) void name(pTHX_ CV* cv __attribute__unused__)
#      define XS_INTERNAL(name) STATIC void name(pTHX_ CV* cv __attribute__unused__)
#    else
#      ifdef __cplusplus
#        define XS_EXTERNAL(name) extern "C" XSPROTO(name)
#        define XS_INTERNAL(name) static XSPROTO(name)
#      else
#        define XS_EXTERNAL(name) XSPROTO(name)
#        define XS_INTERNAL(name) STATIC XSPROTO(name)
#      endif
#    endif
#  endif
#endif

/* perl >= 5.10.0 && perl <= 5.15.1 */


/* The XS_EXTERNAL macro is used for functions that must not be static
 * like the boot XSUB of a module. If perl didn't have an XS_EXTERNAL
 * macro defined, the best we can do is assume XS is the same.
 * Dito for XS_INTERNAL.
 */
#ifndef XS_EXTERNAL
#  define XS_EXTERNAL(name) XS(name)
#endif
#ifndef XS_INTERNAL
#  define XS_INTERNAL(name) XS(name)
#endif

/* Now, finally, after all this mess, we want an ExtUtils::ParseXS
 * internal macro that we're free to redefine for varying linkage due
 * to the EXPORT_XSUB_SYMBOLS XS keyword. This is internal, use
 * XS_EXTERNAL(name) or XS_INTERNAL(name) in your code if you need to!
 */

#undef XS_EUPXS
#if defined(PERL_EUPXS_ALWAYS_EXPORT)
#  define XS_EUPXS(name) XS_EXTERNAL(name)
#else
   /* default to internal */
#  define XS_EUPXS(name) XS_INTERNAL(name)
#endif

#ifndef PERL_ARGS_ASSERT_CROAK_XS_USAGE
#define PERL_ARGS_ASSERT_CROAK_XS_USAGE assert(cv); assert(params)

/* prototype to pass -Wmissing-prototypes */
STATIC void
S_croak_xs_usage(const CV *const cv, const char *const params);

STATIC void
S_croak_xs_usage(const CV *const cv, const char *const params)
{
    const GV *const gv = CvGV(cv);

    PERL_ARGS_ASSERT_CROAK_XS_USAGE;

    if (gv) {
        const char *const gvname = GvNAME(gv);
        const HV *const stash = GvSTASH(gv);
        const char *const hvname = stash ? HvNAME(stash) : NULL;

        if (hvname)
	    Perl_croak_nocontext("Usage: %s::%s(%s)", hvname, gvname, params);
        else
	    Perl_croak_nocontext("Usage: %s(%s)", gvname, params);
    } else {
        /* Pants. I don't think that it should be possible to get here. */
	Perl_croak_nocontext("Usage: CODE(0x%"UVxf")(%s)", PTR2UV(cv), params);
    }
}
#undef  PERL_ARGS_ASSERT_CROAK_XS_USAGE

#define croak_xs_usage        S_croak_xs_usage

#endif

/* NOTE: the prototype of newXSproto() is different in versions of perls,
 * so we define a portable version of newXSproto()
 */
#ifdef newXS_flags
#define newXSproto_portable(name, c_impl, file, proto) newXS_flags(name, c_impl, file, proto, 0)
#else
#define newXSproto_portable(name, c_impl, file, proto) (PL_Sv=(SV*)newXS(name, c_impl, file), sv_setpv(PL_Sv, proto), (CV*)PL_Sv)
#endif /* !defined(newXS_flags) */

#if PERL_VERSION_LE(5, 21, 5)
#  define newXS_deffile(a,b) Perl_newXS(aTHX_ a,b,file)
#else
#  define newXS_deffile(a,b) Perl_newXS_deffile(aTHX_ a,b)
#endif

#line 342 "lib/GoatKCD/Extractor/OpenCV.c"

XS_EUPXS(XS_GoatKCD__Extractor__OpenCV_getlines); /* prototype to pass -Wmissing-prototypes */
XS_EUPXS(XS_GoatKCD__Extractor__OpenCV_getlines)
{
    dVAR; dXSARGS;
    if (items != 5)
       croak_xs_usage(cv,  "input, x, y, width, height");
    {
	IplImage*	input;
	int	x = (int)SvIV(ST(1))
;
	int	y = (int)SvIV(ST(2))
;
	int	width = (int)SvIV(ST(3))
;
	int	height = (int)SvIV(ST(4))
;
	SV *	RETVAL;

	if (sv_isobject(ST(0)) && sv_derived_from(ST(0), "Cv::Image")) {
		input = INT2PTR(IplImage *, SvIV((SV*)SvRV(ST(0))));
	} else if (SvROK(ST(0)) && SvIOK(SvRV(ST(0))) && SvIV(SvRV(ST(0))) == 0) {
		input = (IplImage *)0;
	} else
		Perl_croak(aTHX_ "%s is not of type %s in %s",
			"input", "IplImage *", "GoatKCD::Extractor::OpenCV::getlines")
;
#line 199 "lib/GoatKCD/Extractor/OpenCV.xs"
		RETVAL = process_lines(input,x,y,width,height);
#line 372 "lib/GoatKCD/Extractor/OpenCV.c"
	RETVAL = sv_2mortal(RETVAL);
	ST(0) = RETVAL;
    }
    XSRETURN(1);
}


XS_EUPXS(XS_GoatKCD__Extractor__OpenCV_load_img); /* prototype to pass -Wmissing-prototypes */
XS_EUPXS(XS_GoatKCD__Extractor__OpenCV_load_img)
{
    dVAR; dXSARGS;
    if (items != 1)
       croak_xs_usage(cv,  "file");
    {
	const char*	file = (const char *)SvPV_nolen(ST(0))
;
	IplImage *	RETVAL;
#line 210 "lib/GoatKCD/Extractor/OpenCV.xs"
		RETVAL = load_image(file);
#line 392 "lib/GoatKCD/Extractor/OpenCV.c"
	{
	    SV * RETVALSV;
	    RETVALSV = sv_newmortal();
	    sv_setref_pv(RETVALSV, "Cv::Image", (void*)RETVAL);
	    ST(0) = RETVALSV;
	}
    }
    XSRETURN(1);
}


XS_EUPXS(XS_GoatKCD__Extractor__OpenCV_release_img); /* prototype to pass -Wmissing-prototypes */
XS_EUPXS(XS_GoatKCD__Extractor__OpenCV_release_img)
{
    dVAR; dXSARGS;
    if (items != 1)
       croak_xs_usage(cv,  "img");
    {
	IplImage*	img;
	void *	RETVAL;
	dXSTARG;

	if (sv_isobject(ST(0)) && sv_derived_from(ST(0), "Cv::Image")) {
		img = INT2PTR(IplImage *, SvIV((SV*)SvRV(ST(0))));
	} else if (SvROK(ST(0)) && SvIOK(SvRV(ST(0))) && SvIV(SvRV(ST(0))) == 0) {
		img = (IplImage *)0;
	} else
		Perl_croak(aTHX_ "%s is not of type %s in %s",
			"img", "IplImage *", "GoatKCD::Extractor::OpenCV::release_img")
;
#line 218 "lib/GoatKCD/Extractor/OpenCV.xs"
		release_image(img);
#line 425 "lib/GoatKCD/Extractor/OpenCV.c"
	XSprePUSH; PUSHi(PTR2IV(RETVAL));
    }
    XSRETURN(1);
}

#ifdef __cplusplus
extern "C"
#endif
XS_EXTERNAL(boot_GoatKCD__Extractor__OpenCV); /* prototype to pass -Wmissing-prototypes */
XS_EXTERNAL(boot_GoatKCD__Extractor__OpenCV)
{
#if PERL_VERSION_LE(5, 21, 5)
    dVAR; dXSARGS;
#else
    dVAR; dXSBOOTARGSXSAPIVERCHK;
#endif
#if (PERL_REVISION == 5 && PERL_VERSION < 9)
    char* file = __FILE__;
#else
    const char* file = __FILE__;
#endif

    PERL_UNUSED_VAR(file);

    PERL_UNUSED_VAR(cv); /* -W */
    PERL_UNUSED_VAR(items); /* -W */
#if PERL_VERSION_LE(5, 21, 5)
    XS_VERSION_BOOTCHECK;
#  ifdef XS_APIVERSION_BOOTCHECK
    XS_APIVERSION_BOOTCHECK;
#  endif
#endif

        newXS_deffile("GoatKCD::Extractor::OpenCV::getlines", XS_GoatKCD__Extractor__OpenCV_getlines);
        newXS_deffile("GoatKCD::Extractor::OpenCV::load_img", XS_GoatKCD__Extractor__OpenCV_load_img);
        newXS_deffile("GoatKCD::Extractor::OpenCV::release_img", XS_GoatKCD__Extractor__OpenCV_release_img);
#if PERL_VERSION_LE(5, 21, 5)
#  if PERL_VERSION_GE(5, 9, 0)
    if (PL_unitcheckav)
        call_list(PL_scopestack_ix, PL_unitcheckav);
#  endif
    XSRETURN_YES;
#else
    Perl_xs_boot_epilog(aTHX_ ax);
#endif
}

