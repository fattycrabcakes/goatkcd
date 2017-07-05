#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#undef seed

#include "goatkcd_extractor.h"


MODULE = GoatKCD::Extractor PACKAGE = GoatKCD::Extractor
PROTOTYPES: DISABLE

SV* getlines(extractor,params);
	SV* extractor
	SV* params
	CODE:
		RETVAL = process_lines(extractor,params);
	OUTPUT:
		RETVAL

int load_img(extractor,file)
	SV* extractor
	const char* file
	CODE:
		RETVAL = load_image(extractor,file);
	OUTPUT:
		RETVAL

void* release_img(caller,img)
	SV* caller;
	IplImage* img;
	CODE:
		release_image(img);
	OUTPUT:
		RETVAL
