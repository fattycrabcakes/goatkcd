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
#define SHRINK_BY  15
#define COMPLEXITY 1
#define COLOR	1
#define BW 0


void showImage(IplImage* img,const char* title) {

  cvNamedWindow( title, 1 );
  cvShowImage( title, img );
  cvWaitKey(0);
}

int get_int(HV* hash,const char* k,int kl) {
	if (!hv_exists(hash,k,kl)) {
		return 0;
	} else {
			SV** res  = hv_fetch(hash,k,kl,0);
			return SvIV(res[0]);
	}
}


SV* process_lines(SV* obj,IplImage* orig,SV* p) {

	HV* extractor = (HV*)SvRV(obj);
	HV* params = (HV*)SvRV(p);

	int x = get_int(params,"x",1);
	int y = get_int(params,"y",1);
	int width = get_int(params,"width",5);
	int height = get_int(params,"height",6);
	int mode = get_int(params,"mode",4);

	SV* retval = newSV(0);
	if( !orig ) {
        return retval;
    }
		IplImage* src;
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

  	IplImage* grad = cvCreateImage(size, 8, 1 );
  	IplImage* bw = cvCreateImage(size, 8, 1 );
		CvMemStorage* storage = cvCreateMemStorage(0);


		IplImage* morph = cvCloneImage(src);
		IplImage* transitional;

		if (mode==BW) {
				transitional = cvCreateImage(size,8,1);
  			cvThreshold(src,transitional,128.0,255,CV_THRESH_BINARY);
		} else {
				transitional = cvCloneImage(src);
		}

		//showImage(transitional,"what");

  	IplConvKernel* kernel = cvCreateStructuringElementEx(3,3,0,0,MORPH_ELLIPSE,NULL);
  	cvMorphologyEx(morph,grad,storage,kernel,MORPH_GRADIENT,1);
  	cvThreshold(grad,bw,0.0,225.0, THRESH_BINARY | THRESH_OTSU);


		cvReleaseImage(&morph);
		cvReleaseImage(&grad);
	
		
		IplImage* gray = cvCreateImage(size, 8, 1 );
		cvCanny( transitional, gray, 20, 138, 3 );
		cvReleaseImage(&transitional);


  	CvSeq *contours = cvCreateSeq(0, sizeof(CvSeq), sizeof(CvPoint), storage);
		cvClearMemStorage(storage);

  int count = cvFindContours(bw, storage, &contours, sizeof(CvContour), CV_RETR_LIST,CV_CHAIN_APPROX_SIMPLE, cvPoint(0,0));
	cvReleaseImage(&bw);

  if (1) {
 	for(; contours!=0; contours = contours->h_next) {
  	CvRect rect = cvBoundingRect(contours,0);
		/* delete detected shapes from outlines to reduce noise. */
    	if (contours->total>=12) {
						if (mode==BW) {
      				cvDrawContours(gray,contours,CV_RGB(0,0,0),CV_RGB(0,0,0),0,-1,8,cvPoint(0,0));
      				cvDrawContours(gray,contours,CV_RGB(0,0,0),CV_RGB(0,0,0),0,3,8,cvPoint(0,0));
						} else {
							cvRectangle(gray,cvPoint(rect.x+SHRINK_BY,rect.y+SHRINK_BY),cvPoint(rect.x+rect.width-SHRINK_BY,rect.y+rect.height-SHRINK_BY),CV_RGB(0,0,0),-1,8,0);
							cvRectangle(gray,cvPoint(rect.x+SHRINK_BY,rect.y+SHRINK_BY),cvPoint(rect.x+rect.width-SHRINK_BY,rect.y+rect.height-SHRINK_BY),CV_RGB(0,0,0),2,8,0);
						}
				}
    	}
		}

		//showImage(gray,"gray");
		
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



	cvClearMemStorage(storage);

	/* lines = cvHoughLines2( gray, storage, CV_HOUGH_PROBABILISTIC, 1, (CV_PI/180), 50, 50, 10 );

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
	*/

	cvReleaseImage(&src);
	cvReleaseMemStorage(&storage);
	cvReleaseStructuringElement(&kernel);
	cvReleaseMemStorage(&contours);



	//hv_store(data,"checklines",10,newRV((SV*)plines),0);
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
	


MODULE = GoatKCD::Extractor::OpenCV  PACKAGE = GoatKCD::Extractor::OpenCV
PROTOTYPES: DISABLE

SV*
getlines(extractor,input,params);
	SV* extractor
	IplImage* input
	SV* params
	CODE:
		RETVAL = process_lines(extractor,input,params);
	OUTPUT:
		RETVAL

MODULE = GoatKCD::Extractor::OpenCV PACKAGE = GoatKCD::Extractor::OpenCV
PROTOTYPES: DISABLE

IplImage*
load_img(file)
	const char* file
	CODE:
		RETVAL = load_image(file);
	OUTPUT:
		RETVAL

void *
release_img(img)
	IplImage* img;
	CODE:
		release_image(img);
	OUTPUT:
		RETVAL
