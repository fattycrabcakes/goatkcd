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
#define SHRINK_BY  5
#define COMPLEXITY 1


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
        if (abs(pt2.x-pt1.x)<=2 || abs(pt1.y-pt2.y)<=2) {
            cvLine( color_img, pt1, pt2, CV_RGB(0,0xff,0x00), 1, CV_AA, 0 );
        }
    }
}



SV* process_lines(char* filename,int minLength,int rho,int theta,int threshold) {

    IplImage* src = cvLoadImage( filename, 0 );

	SV* retval = newSV(0);
	if( !src ) {
        return retval;
    }

	 CvSize size = cvGetSize(src);

    int i;

	/* Detect and eliminate text and complex shapes */

    IplImage* morph = cvCloneImage(src);
    IplImage* grad = cvCreateImage(size, 8, 1 );
    IplImage* bw = cvCreateImage(size, 8, 1 );
    IplImage* final = cvCreateImage(size,8,1);

    IplConvKernel* kernel = cvCreateStructuringElementEx(3,3,0,0,MORPH_ELLIPSE,NULL);

    cvMorphologyEx(morph,grad,cvCreateMemStorage(0),kernel,MORPH_GRADIENT,1);
    cvThreshold(grad,bw,0.0,255.0, THRESH_BINARY | THRESH_OTSU);
    kernel = cvCreateStructuringElementEx(9,1,0,0,MORPH_RECT,NULL);
    cvMorphologyEx(bw,final,cvCreateMemStorage(0),kernel,MORPH_CLOSE,1);

	/* Canny image filter for the cmic frames. */	
	IplImage* gray = cvCreateImage(size, 8, 1 );
	cvCanny( src, gray, 20, 200, 3 );

    CvMemStorage *storage = cvCreateMemStorage(0);
    CvSeq *contours = cvCreateSeq(0, sizeof(CvSeq), sizeof(CvPoint), storage);
    int count = cvFindContours(bw, storage, &contours, sizeof(CvContour), CV_RETR_LIST,CV_CHAIN_APPROX_SIMPLE, cvPoint(0,0));

    if (1) {
        for(; contours!=0; contours = contours->h_next) {
            if (contours->total>COMPLEXITY) {
                CvRect rect = cvBoundingRect(contours,0);
				/* delete detected shapes from outlines to reduce noise. */
                cvRectangle(gray,cvPoint(rect.x+SHRINK_BY,rect.y+SHRINK_BY),cvPoint(rect.x+rect.width-SHRINK_BY,rect.y+rect.height-SHRINK_BY),CV_RGB(0,0,0),-1,8,0);
            }
        }
    }


    CvSeq* lines = cvHoughLines2( gray, cvCreateMemStorage(0), CV_HOUGH_PROBABILISTIC, 1, (CV_PI/180), rho, theta, threshold );

	AV* plines = newAV();
    lines = cvHoughLines2( gray, cvCreateMemStorage(0), CV_HOUGH_STANDARD, 1, CV_PI/180, 50, 50, 10 );
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
        if (abs(pt2.x-pt1.x)<=2 || abs(pt1.y-pt2.y)<=2) {
			AV* ltt;
            ltt  = newAV();
			av_push(ltt,newSViv(pt1.x));
            av_push(ltt,newSViv(pt1.y));
			av_push(ltt,newSViv(pt2.x));
            av_push(ltt,newSViv(pt2.y));
			av_push(plines,newRV((SV*)ltt));
        }
	}

	return newRV((SV*)plines);
}


MODULE = GoatKCD::Extractor::OpenCV  PACKAGE = GoatKCD::Extractor::OpenCV
PROTOTYPES: DISABLE

SV*
getlines(input,minLength,rho,theta,threshold)
	char* input
	int minLength
	int rho
	int theta
	int threshold
	CODE:
		RETVAL = process_lines(input,minLength,rho,theta,threshold);
	OUTPUT:
		RETVAL

MODULE = GoatKCD::Extractor::OpenCV  PACKAGE = GoatKCD::Extractor::OpenCV
int
echo(input)
    int input
	CODE:
    RETVAL = (input % 2 == 0);
	OUTPUT:
    RETVAL
