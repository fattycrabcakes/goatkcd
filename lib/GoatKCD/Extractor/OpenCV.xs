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
	


MODULE = GoatKCD::Extractor::OpenCV  PACKAGE = GoatKCD::Extractor::OpenCV
PROTOTYPES: DISABLE

SV*
getlines(input,x,y,width,height)
	IplImage* input
	int x
	int y
	int width
	int height
	CODE:
		RETVAL = process_lines(input,x,y,width,height);
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
