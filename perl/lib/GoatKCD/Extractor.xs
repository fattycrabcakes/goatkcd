#define PERL
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
