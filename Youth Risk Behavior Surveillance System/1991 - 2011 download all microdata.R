# analyze survey data for free (http://asdfree.com) with the r language
# youth risk behavior surveillance system
# 1991 - 2011

# # # # # # # # # # # # # # # # #
# # block of code to run this # #
# # # # # # # # # # # # # # # # #
# library(downloader)
# setwd( "C:/My Directory/YRBSS/" )
# years.to.download <- seq( 1991 , 2011 , by = 2 )
# source_url( "https://raw.github.com/ajdamico/usgsd/master/Youth%20Risk%20Behavior%20Surveillance%20System/1991%20-%202011%20download%20all%20microdata.R" , prompt = FALSE , echo = TRUE )
# # # # # # # # # # # # # # #
# # end of auto-run block # #
# # # # # # # # # # # # # # #

# if you have never used the r language before,
# watch this two minute video i made outlining
# how to run this script from start to finish
# http://www.screenr.com/Zpd8

# anthony joseph damico
# ajdamico@gmail.com

# if you use this script for a project, please send me a note
# it's always nice to hear about how people are using this stuff

# for further reading on cross-package comparisons, see:
# http://journal.r-project.org/archive/2009-2/RJournal_2009-2_Damico.pdf


##############################################################################################
# download every file from every year of the Youth Risk Behavior Surveillance System with R  #
# then save every file as an R data frame (.rda) so future analyses can be conducted rapidly #
##############################################################################################


# set your working directory.
# all YRBSS data files will be stored here
# after downloading.
# use forward slashes instead of back slashes

# uncomment this line by removing the `#` at the front..
# setwd( "C:/My Directory/YRBSS/" )
# ..in order to set your current working directory



# remove the # in order to run this install.packages line only once
# install.packages( "SAScii" )



# uncomment this line to download every available year
# years.to.download <- seq( 1991 , 2011 , by = 2 )

# uncomment this line to only download the 2011 single-year file and no others
# years.to.download <- 2011

# uncomment these lines to only download the 1991 and also 2001 thru 2011 files
# years.to.download <- c( 1991 , seq( 2001 , 2011 , by = 2 ) )


# no need to edit anything below this line #


# # # # # # # # #
# program start #
# # # # # # # # #


library(SAScii) 	# load the SAScii package (imports ascii data with a SAS script)


# the yrbss sas importation scripts contain some oddities..
# ..so construct a function that flips two blocks of characters within a string
sas.switcharoo <-
	function( sas_ri , variable ){
			
		# find the first occurrence of the variable inside the sas importation syntax
		ows.fo <- grep( variable , sas_ri )[1]
		
		# extract that single line of code
		old.ws <- sas_ri[ ows.fo ]
		
		# find the ending position of the variable within the current string
		end.position.of.var <- eval( parse( text = gsub( paste( "@(.*)" , variable , "(.*)\\.(.*)" ) , "\\1 + \\2" , old.ws ) ) ) - 1
		
		# find the replacement string
		new.ws <- gsub( paste( "@(.*)" , variable , "(.*)\\." ) , paste0( variable , " \\1-" , end.position.of.var , " ." ) , old.ws , perl = TRUE )
		
		# replace the old block with the new one
		# throughout the sas importation instructions
		gsub( old.ws , new.ws , sas_ri )
		# since the result of this `gsub` function
		# is the last line of the `sas.switcharoo` function
		# the function will return that result.
	}
		

#create a temporary file
tf <- tempfile()


# loop through each possible yrbss year
for ( year in years.to.download ){

	# print the current year to the screen
	print( year )

	# construct the full ftp path of
	# the current year yrbss ascii data file
	fn <- 
		paste0( 
			"ftp://ftp.cdc.gov/pub/data/yrbs/" , 
			year , 
			"/YRBS" ,
			year , 
			".dat"
		)
	
	# construct the full ftp path of
	# the current year's sas importation instructions
	sas_ri <-
		paste0(
			"ftp://ftp.cdc.gov/pub/data/yrbs/" ,
			year , 
			"/YRBS_" ,
			year , 
			"_SAS_Input_Program.sas"
		)
	
	
	# read those sas importation instructions
	# into working memory immediately
	sas_text <- tolower( readLines( sas_ri ) )

	# the R SAScii package cannot handle `$char8.`
	# so here's the first half of q4 patch,
	# where those lines of the sas importation scripts
	# are manually dealt with
	sas_text <- gsub( "q4orig $char8." , "q4orig  8.0" , sas_text , fixed = TRUE )
	
	# find all strings that begin with "@"
	at.beginners <- which( substr( sas_text , 1 , 1 ) == "@" )
	
	# remove all "" empty strings
	no.empty <- lapply( strsplit( sas_text[ at.beginners ] , " " ) , function( z ) z[ z != '' ] )
	
	# take all of the _second_ elements
	vars.to.flip <- lapply( no.empty , "[[" , 2 )
	
	# repeatedly run the previously-constructed `sas.switcharoo` function
	# on all of the lines that need lines flipped
	for ( var.to.flip in vars.to.flip ) sas_text <- sas.switcharoo( sas_text , var.to.flip )	
	
	# and here's the second half of q4 patch
	# q4orig should be treated as a string, not numeric
	sas_text <- gsub( "q4orig" , "q4orig $" , sas_text , fixed = TRUE )

	
	# here's some more code to deal with quirky sas importation instructions:
	
	# if the first column position isn't at one..
	first.instruction <- grep( 'input' , SAS.uncomment( sas_text , '/*' , '*/') ) + 1
	
	if ( !grepl( " 1-" , sas_text[ first.instruction ] ) ){
	
		# find the first position
		dash.position <- gregexpr( "-" , sas_text[ first.instruction ] )[[1]][1]
		start.blank <- as.numeric( substr( sas_text[ first.instruction ] , dash.position - 3 , dash.position - 1 ) ) - 1
		
		# add a blank in sas_text
		sas_text <-
			c(
				sas_text[ 1:( first.instruction - 1 ) ] ,
				paste0( "blank $ 1-" , start.blank ) ,
				sas_text[ first.instruction:length( sas_text ) ]
			)	
		# adding this `blank` will effectively create a column full of nothing
		# in the final data file as read-in by read.SAScii
		# ..but that'll get thrown out later
	}
	
	# save the final sas importation script to
	# a file on the hard disk (since ?read.SAScii and ?parse.SAScii
	# require a file, not something read into working memory)
	writeLines( sas_text , tf )
	
	# make a first attempt at reading in the full file
	broken <- try( x <- read.SAScii( fn , tf ) , silent = TRUE )

	# if that doesn't work, try try again.
	while( class( broken ) == 'try-error' ){
		
		# wait sixty seconds
		Sys.sleep( 60 )
	
		# exact same command.  weird, huh?
		broken <- try( x <- read.SAScii( fn , tf ) , silent = TRUE )

	}

	# convert all column names to lowercase
	names( x ) <- tolower( names( x ) )

	# throw out all columns called `blank`
	# which we'd added as a band-aid above.
	x <- x[ , !( names( x ) %in% 'blank' ) ]
		
	# add a column full of ones
	x$one <- 1
	
	# save the current `x` data.frame to the local disk
	save( x , file = paste0( "yrbs" , year , ".rda" ) )
	
	# remove `x` from working memory
	rm( x )
	
	# clear up RAM
	gc()
}


# for more details on how to work with data in r
# check out my two minute tutorial video site
# http://www.twotorials.com/

# dear everyone: please contribute your script.
# have you written syntax that precisely matches an official publication?
message( "if others might benefit, send your code to ajdamico@gmail.com" )
# http://asdfree.com needs more user contributions

# let's play the which one of these things doesn't belong game:
# "only you can prevent forest fires" -smokey bear
# "take a bite out of crime" -mcgruff the crime pooch
# "plz gimme your statistical programming" -anthony damico
