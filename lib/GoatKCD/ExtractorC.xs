#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#undef seed

#include <opencv/cv.h>
#include <opencv/highgui.h>
#include <opencv2/highgui/highgui_c.h>
#include <math.h>
#include <stdio.h>


SV* process_lines(const char* filename) {

    IplImage* src = cvLoadImage( filename, 0 );

	SV* retval = newSV(0);
	if( !src ) {
        return retval;
    }
	int i;
	
    CvSeq* lines = 0;

    IplImage* dst = cvCreateImage( cvGetSize(src), 8, 1 );
    IplImage* color_dst = cvCreateImage( cvGetSize(src), 8, 3 );

    cvCanny( src, dst, 50, 200, 3 );
    cvCvtColor( dst, color_dst, CV_GRAY2BGR );

    lines = cvHoughLines2( dst, cvCreateMemStorage(0), CV_HOUGH_PROBABILISTIC, 1, CV_PI/180, 50, 50, 10 );

	AV* plines = newAV();
	for( i = 0; i < lines->total; i++ ) {
		CvPoint* line = (CvPoint*)cvGetSeqElem(lines,i);
		// mostly straight lines, lank you very much.
        if (abs(line[0].x-line[1].x)<3 || abs(line[0].y-line[1].y)<3) {
			int tmp;
			// fmake sure they all point from the top left
			if (line[0].x<line[1].x) {
				tmp = line[0].x;	
				line[0].x = line[1].x;
				line[1].x=tmp;
			}
			if (line[0].y<line[1].y) {
				tmp = line[0].y;    
                line[0].y = line[1].y;
                line[1].y=tmp;
            }
			AV* ltt;
			ltt  = newAV();
			for (int j=0;j<2;j++) {
				av_push(ltt,newSViv((int)line[j].x));
				av_push(ltt,newSViv(line[j].y));
			}
			av_push(plines,newRV((SV*)ltt));
			cvLine( color_dst, line[0], line[1], CV_RGB(0,0,0xff), 1, CV_AA, 0 );
        }
    }

	cvNamedWindow( "Hough", 1 );
    cvShowImage( "Hough", color_dst );
    cvWaitKey(0);

	//PUSHs(newRV((SV*)plines));
	return newRV((SV*)plines);
	
}


MODULE = GoatKCD::ExtractorC  PACKAGE = GoatKCD::ExtractorC  
PROTOTYPES: DISABLE

SV*
getlines(input)
	char* input
	CODE:
		RETVAL = process_lines(input);
	OUTPUT:
		RETVAL

MODULE = GoatKCD::ExtractorC  PACKAGE = GoatKCD::ExtractorC
int
echo(input)
    int input
	CODE:
    RETVAL = (input % 2 == 0);
	OUTPUT:
    RETVAL
