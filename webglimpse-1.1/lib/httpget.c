#include <errno.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/param.h>
#include <sys/time.h>
#if _AIX
#include <sys/select.h>
#endif
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <signal.h>
#include "utils.h"

/*
#define DEBUG
#define RAWGET
*/

#ifndef USERID
#define USERID "glimpse@cs.arizona.edu"
#endif

#define APPNAME "HTTPGET/1.0 GlimpseHTTP/3.0"


/* prototypes */
int get_url(char *url, FILE *outfile);

char *useraddr=USERID;
char *appname=APPNAME;
fd_set readset;
struct timeval timeout;
#define TIMEOUT_SEC 30
#define TIMEOUT_USEC 0
int max_time=30;
int inter_time=10;



char errbuf[ERRBUF_SIZE];

/*----------------------------------------------------------------------*/
void alarm_handler (int a){
	/* timeout! */
	ERROR0("Timeout.");
}

/*----------------------------------------------------------------------*/
/* generic error routine */
void error(char *errmsg){
   fprintf(stdout, "ERROR: %s\n", errmsg);
	exit(-100);
}

/*-----------------------------------------------------------------------*/
int wait_for_select(int s){
	int selrc;

	selrc=select(s+1, &readset, NULL, NULL, &timeout);

	if(selrc==0){
		ERROR0("select (inter-arrival) timeout");
	}else if(selrc<0){
		ERROR0("socket error");
	}
	return selrc;
}

/*-----------------------------------------------------------------------*/
int anychars(char *name){
	int namesize = strlen(name);
	int i;

	for(i=0; i<namesize; i++){
		if(isalpha(name[i])) return 1;
	}
	return 0;
}

/*-----------------------------------------------------------------------*/
int call_socket(char *hostname, int portnum){ 
	struct sockaddr_in sa;
	struct hostent     *hp;
	int s;
	int on=1;

	/* if the host has any characters in it, call gethostbyname */
	if (anychars(hostname)){
		if ((hp= gethostbyname(hostname)) == NULL) { /* do we know the host's */
			errno= ECONNREFUSED;                       /* address? */
			ERROR1("Cannot find host address for %s.", hostname);
			return(-1);                                /* no */
		}
	}else{
		unsigned int addr = inet_addr(hostname);

		if ((hp= gethostbyaddr((void *)&addr,sizeof(addr), AF_INET)) == NULL) 
		{ /* do we know the host's */
			errno= ECONNREFUSED;                       /* address? */
			ERROR1("Cannot find host address for %s.", hostname);
			return(-1);                                /* no */
		}
	}

/****************************************************************/
/*	In earlier version of solaris, bzero is only supported	*/
/*	in BSD compatible library.				*/
/*	So we change bzero to memset, bcopy to memcpy.		*/
/*								*/
/*			Dachuan Zhang, June 1st, 1996.		*/
/****************************************************************/

	memset((char *)&sa, 0, sizeof(sa));
	memcpy((char *)&sa.sin_addr, hp->h_addr, hp->h_length);
	sa.sin_family= hp->h_addrtype;
	sa.sin_port= htons((u_short)portnum);

	if ((s= socket(hp->h_addrtype,SOCK_STREAM,0)) < 0){
	   /* get socket */
		ERROR0("call to socket failed");
		return(-1);
	}
	if (connect(s,(struct sockaddr *)&sa,sizeof(sa)) < 0) {       /* connect */
		shutdown(s, 2);
		ERROR0("call to connect failed");
		return(-1);
	}

	/* undo the alarm */
	alarm(0);

	setsockopt(s, SOL_SOCKET, SO_REUSEADDR, (void *)&on, sizeof(on));
#ifdef DEBUG
	printf("Successfully connected.\n");
#endif
	return(s);
}


/*----------------------------------------------------------------------*/
int getline(char *buf, int maxsize, int s){
	int numbytes=0;

	/* leave space for the null */
	maxsize--;

	/* assume no lines greater than buf */
	while(1){
		if(read(s, &buf[numbytes], 1)<1) break;
		numbytes++;
		if((buf[numbytes-1]=='\n') ||
			(numbytes==maxsize)){
			buf[numbytes]='\0';
			return numbytes;
		}
	}
	buf[numbytes]='\0';
	return numbytes;
}
	
/*----------------------------------------------------------------------*/
int get_http(int sock, char *path, FILE *outfile){
	int rc;
	int code;
	float version;
	/* NOTE: if you change any array sizes, change them in the scanfs, etc. */
	char buf[1024];
	char tmpbuf[32];
	char location[128];
	char c;

	/* write the request to the socket */
	/* if no path specified, make it / */
	sprintf(buf, "GET %s HTTP/1.0\r\n"
					"User-Agent: %s\r\n"
					"Accept: text/*\r\n\r\n", path[0] ? path : "/", appname, useraddr);
	rc = write(sock, buf, strlen(buf));

#ifdef DEBUG
	printf("waiting for reply...\n");
#endif
	

	/* set up the select stuff */
	/* clear the read set */
	FD_ZERO(&readset);
	FD_SET(sock,&readset);
	/* set the timeout */
	timeout.tv_sec = inter_time;
	timeout.tv_usec = 0;

#ifndef RAWGET
	/* first, get the header */
	getline(buf, sizeof(buf), sock);

	/* get the protocol and the code */
	sscanf(buf, "%4s/%4f %3d", tmpbuf, &version, &code);

#ifdef DEBUG
	printf("Got header... HTTP: %s, version: %f, code: %d\n",
		tmpbuf, version, code);
#endif

	/* check the header */
	if(strcmp(tmpbuf, "HTTP") ||
		version <= 0.0 ||
		code < 200 ||
		code > 503){
		/* error with the header */
		ERROR0("Error with the header.  Aborting.\n");
	}

	/* check the code */
	switch(code){
		case 400:       ERROR0("Bad request");
		case 401:       ERROR0("Unauthorized");
		case 403:       ERROR0("Forbidden");
		case 404:       ERROR0("Not Found");
		case 500:       ERROR0("Internal Server Error");
		case 501:       ERROR0("Not Implemented");
		case 502:       ERROR0("Bad Gateway");
		case 503:       ERROR0("Service Unavailable");
	}


	/* skip lines until we get an empty one */
	location[0]='\0';
	while( getline(buf, sizeof(buf), sock) > 0 ){
#ifdef DEBUG
		printf("Header line: %s", buf);
#endif
		sscanf(buf, "%31s", tmpbuf);
		if(strlen(tmpbuf)==0) break;
		if(strcmp(tmpbuf, "Location:")==0){
			sscanf(buf, "%31s %127s", tmpbuf, location);
		}
		tmpbuf[0]='\0';
	}

	/* check for redirect */
	if(code==301 || code==302){
		printf("Redirect: %s\n", location);
		/* close the current socket and fd, and call for a new location */
		shutdown(sock, 2);
		/* for recursion, do:
		return get_url(location, outfile);
		*/
		/* I will just exit, since I need to return the address */
		exit(0);
	}
#endif
/* END OF RAWGET IFDEF */

	/* get the body */
	wait_for_select(sock);
	while( rc = read(sock, buf, sizeof(buf)) ){
		fwrite(buf, rc, 1, outfile);
		wait_for_select(sock);
	}

	/* close the socket */
	shutdown(sock, 2);

	return 1;
}

/*----------------------------------------------------------------------*/
int parse_url(char *url, char **serverstrp, int *portp, char **pathstrp){
	char buf[256];
	int serverlen, numread=0;

	/* go through the url */
	/* reset url to point PAST the http:// */
	/* assume it's always 7 chars! */
	url = url+7;

	/* no http:// now... server is simply up to the next / or : */
	sscanf(url, "%255[^/:]", buf);
	serverlen = strlen(buf);
	*serverstrp = (char *)malloc(serverlen+1);
	strcpy(*serverstrp, buf);

	if(url[serverlen]==':'){
		/* get the port */
		sscanf(&url[serverlen+1], "%d%n", portp, &numread);
		/* add one to go PAST it */
		numread++;
	}else{
		*portp = 80;
	}

	/* the path is a pointer into the rest of url */
	*pathstrp = &url[serverlen+numread];

	return 0;
}

/*----------------------------------------------------------------------*/
int get_url(char *url, FILE *outfile){
	char *server;
	int port;
	char *path;
	int rc, s;

	rc = parse_url(url, &server, &port, &path);
	if(rc<0){
		ERROR1("Problem with parsing url %s", url);
	}

#ifdef DEBUG
	printf("http connection to %s:%d, path: %s\n", server, port, path);
#endif

	s = call_socket(server, port);
	if(s==-1){
		/* error msgs in call_socket */
		return -1;
	}

	/* we can free memory for server string */
	free(server);

	return get_http(s, path, outfile);
}

/*----------------------------------------------------------------------*/
int main(int argc, char *argv[]){
	int rc;
	FILE *outfile;
	int index;
	char *outfilename=NULL;

	if(argc<2){
		ERROR1("Format: %s <http://server[:port]/path> [-o <outputfile>] [-u userid@server.location] [-t max_time] [-i inter_time]",
			argv[0]);
	}

	/* parse args */
	for(index=1; index<argc; index++){
		if(strncmp(argv[index], "-t", 2)==0){
			max_time = atoi(argv[++index]);
		}
		else if(strncmp(argv[index], "-i", 2)==0){
			inter_time = atoi(argv[++index]);
		}
		else if(strncmp(argv[index], "-u", 2)==0){
			useraddr = argv[++index];
		}
		else if(strncmp(argv[index], "-o", 2)==0){
			outfilename = argv[++index];
		}
	}

	/* install the handler */
	signal(SIGALRM, alarm_handler);
	alarm(max_time);
	/* ### TO DO -- make it work okay with recursion */

	/* open the file */
	if(outfilename==NULL){
		outfile = stdout;
	}else{
		outfile = fopen(outfilename, "w");
		if(outfile==NULL){
			ERROR1("Cannot open outfile %s", argv[2]);
		}
	}

	rc = get_url(argv[1], outfile);

	if(rc<0){
		ERROR0("Cannot get page.");
	}
}
