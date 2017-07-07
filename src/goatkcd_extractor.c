#include "goatkcd_extractor.h"


static IplImage* input;
void showImage(IplImage* img,const char* title) {
  	cvNamedWindow( title, 1 );
  	cvShowImage( title, img );
  	cvWaitKey(0);
}
int get_param_int(HV* hash,const char* k) {
	if (!hv_exists(hash,k,strlen(k))) {
		return 0;
	} else {
		SV** res  = hv_fetch(hash,k,strlen(k),0);
		return SvIV(res[0]);
	}
}


SV* process_lines(SV* obj,SV* p) {

	HV* extractor = (HV*)SvRV(obj);
	HV* params = (HV*)SvRV(p);

	int x = get_param_int(params,"x");
	int y = get_param_int(params,"y");
	int width = get_param_int(params,"width");
	int height = get_param_int(params,"height");
	int mode = get_param_int(params,"mode");
	int methor = get_param_int(params,"mode");
	

	SV* retval = newSV(0);
	if(input==NULL) {
        return retval;
    }
	IplImage* src;

    if (width<1 && height<1) {
		src = cvCloneImage(input);
	} else {
		cvSetImageROI(input,cvRect(x,y,width,height));
		src = cvCreateImage(cvGetSize(input),8,1);
		cvCopy(input,src,NULL);
		cvResetImageROI(input);
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

	AV* parallelograms = newAV();

  	if (1) {
 		for(; contours!=0; contours = contours->h_next) {
  			CvRect rect = cvBoundingRect(contours,0);
    		if (contours->total>=CONTOUR_COMPLEXITY) {
				if (mode==BW) {
      				cvDrawContours(gray,contours,CV_RGB(0,0,0),CV_RGB(0,0,0),0,-1,8,cvPoint(0,0));
      				cvDrawContours(gray,contours,CV_RGB(0,0,0),CV_RGB(0,0,0),0,2,8,cvPoint(0,0));
				} else {
					cvRectangle(gray,cvPoint(
						rect.x+SHRINK_BY,rect.y+SHRINK_BY),cvPoint(rect.x+rect.width-SHRINK_BY,
						rect.y+rect.height-SHRINK_BY),CV_RGB(0,0,0),-1,8,0
					);
					cvRectangle(gray,cvPoint(
						rect.x+SHRINK_BY,rect.y+SHRINK_BY),cvPoint(rect.x+rect.width-SHRINK_BY,
						rect.y+rect.height-SHRINK_BY),CV_RGB(0,0,0),2,8,0
					);
				}
			} else if (contours->total==4) {
				if (rect.width>100 && rect.height>100) {
					AV* frame = newAV();
					av_push(frame,newSViv(rect.x));
					av_push(frame,newSViv(rect.y));
					av_push(frame,newSViv(rect.width));
					av_push(frame,newSViv(rect.height));
					av_push(parallelograms,newRV((SV*)frame));
				}
			}
    	}
	}

	HV* data = newHV();
	hv_stores(data,"contur_rect",newRV((SV*)parallelograms));

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

	cvClearMemStorage(lines->storage);
	cvReleaseImage(&src);
	cvReleaseMemStorage(&storage);
	cvReleaseStructuringElement(&kernel);
	cvReleaseMemStorage(&contours);

	return newRV((SV*)data);
}

int load_image(SV* caller,const char* filename) {

	cvReleaseImage(&input);
	input = cvLoadImage( filename, 0 );
	if (input==NULL) {
		return 0;
	} else {
		return 1;
	}
}
void release_image(IplImage* img) {
	if (img==NULL) {
		return;
	}
	cvReleaseImage(&input);
}
	
	

