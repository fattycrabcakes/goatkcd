/*
http://benjithian.sg/2012/12/simple-background-subtraction/
Simple Background Subtraction. Simple stuff.
*/
#include <stdio.h>
#include <curl/curl.h>
#include <sstream> 
#include <iostream>
#include <vector> 
#include <opencv2/opencv.hpp>

//curl writefunction to be passed as a parameter
size_t write_data(char *ptr, size_t size, size_t nmemb, void *userdata) {
    std::ostringstream *stream = (std::ostringstream*)userdata;
    size_t count = size * nmemb;
    stream->write(ptr, count);
    return count;
}

//function to retrieve the image as Cv::Mat data type
cv::Mat curlImg()
{
	CURL *curl;
	CURLcode res;
	std::ostringstream stream;
	curl = curl_easy_init();
    curl_easy_setopt(curl, CURLOPT_URL, "http://192.168.0.108:8080/shot.jpg"); //the JPEG Frame url
	curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_data); // pass the writefunction
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &stream); // pass the stream ptr when the writefunction is called
	res = curl_easy_perform(curl); // start curl
	std::string output = stream.str(); // convert the stream into a string
	curl_easy_cleanup(curl); // cleanup
	std::vector<char> data = std::vector<char>( output.begin(), output.end() ); //convert string into a vector
	cv::Mat data_mat = cv::Mat(data); // create the cv::Mat datatype from the vector
	cv::Mat image = cv::imdecode(data_mat,1); //read an image from memory buffer
	cv::cvtColor(image,image, CV_BGR2GRAY);//Convert to GreyScale
	return image;
}
int main(void)
{
	cv::namedWindow( "Image output", CV_WINDOW_AUTOSIZE );
	int i = 1;
	cv::Mat image = curlImg(); // get the image frame
	while(1)
	{
		if ( i == 1 ) // Update the background every 100*33ms
		{
			i = 100;
			image = curlImg(); // get the image frame
		}
		i--;
		char c = cvWaitKey(33); // sleep for 33ms or till a key is pressed (put more then ur camera framerate mine is 30ms)
		cv::Mat image2 = curlImg(); // the image that is constantly being updated
		cv::absdiff(image,image2,image2);// Absolute differences between the 2 images 
		cv::threshold(image2,image2,15,255,CV_THRESH_BINARY); // set threshold to ignore small differences you can also use inrange function
		cv::imshow("Image output",image2); // display image
		c = cvWaitKey(33);
		if ( c == 27 ) break; // break if ESC is pressed		
	}
	cv::destroyWindow("Image output");
}
