#define MORPH_ELLIPSE   2
#define MORPH_GRADIENT  4
#define MORPH_RECT  0
#define MORPH_CLOSE 3
#define THRESH_BINARY 0
#define THRESH_OTSU 8
#define SHRINK_BY  15
#define COMPLEXITY 1
#define COLOR   1
#define BW 0
#define CONTOUR_COMPLEXITY 16
#define METHOD_LINES 0
#define METHOD_CONTOURS 1

typedef struct goat_extractor_params {
	int x;
	int y;
	int width;
	int height;
	int mode;
	int method;
} goat_extractor_params;


void showImage(IplImage* img,const char* title);
int get_param_int(HV* hash,const char* k);
SV* process_lines(SV* obj,SV* p);
int load_image(SV* caller,const char* filename);
void release_image(IplImage* img);
SV* extract_lines(IplImage *img);
SV* extract_contours(IplImage *img);


