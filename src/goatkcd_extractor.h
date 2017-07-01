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

void showImage(IplImage* img,const char* title);
int get_int(HV* hash,const char* k,int kl);
SV* process_lines(SV* obj,SV* p);
int load_image(SV* caller,const char* filename);
void release_image(IplImage* img);
