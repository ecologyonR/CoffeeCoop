## This is code to reorganize the data from many small files into one long dataframe

## Andrew MacDonald, June 2013

library(lubridate)
## read in all the data
## code taken directly from do.accounts.R
## LOAD info AND people DATA
info <- read.csv("data/info.csv", as.is=TRUE,comment.char="#")
people <- read.csv("data/people.csv", as.is=TRUE, na.strings="")
date <- info$Date
nd <- length(date)

## QUALITY CHECKS
## makes sure all other dates are formatted correctly.
if ( any(as.character(as.Date(date[-nd])) != date[-nd]) )
  stop("Non-future dates must be in format YYYY-MM-DD")

files <- sprintf("data/%s.csv", info$Date)
if ( !all(file.exists(files)) ) # all files must exist!
  stop("Data sheets missing: ",
       paste(basename(files)[!file.exists(files)], collapse=", "))

## Extra files in the data directory are almost certainly bad news.
extra <- setdiff(c("info.csv", "people.csv", basename(files)),
                 dir("data"))
if ( length(extra) > 0 )
  stop("Extra files found in data directory: ",
       paste(extra, collapse=", "))

## LOAD FORMER DATA FILES

read.data <- function(filename){
  d <- read.csv(filename, stringsAsFactors=FALSE)
  cols <- c("ID", "Name", "Payment", "Payment.Date", "Milk", "Coffee", "Tea")
  if ( !all(cols %in% names(d)) )
    stop(sprintf("Missing columns in %s: %s", filename,
                 paste(setdiff(cols, names(d)), collapse=", ")))
  
  d[is.na(d)] <- 0
  
  # Exit if duplicates are found
  if( any(duplicated(d$ID)) ){ 
    cat("PROBLEM IN ",filename,": DUPLICATES! \n")
    error('\nDuplicates found. EXIT. \n')
  }
  ## MODIFICATION include the date
  data_date <- gsub(".csv","",basename(filename))
  d <- cbind(data_date,d)
  return(d)
}


dat <- lapply(files, read.data)


## rbind all of it?  Are the columns the same?

which(sapply(dat,ncol)==10)
dat[[20]]  ## weird year with extra data
dat[[20]] <- dat[[20]][!names(dat[[20]])%in%c("NA.","NA..1")]
sapply(dat,ncol)

all_data <- do.call(what=rbind,dat)
## remove lines without consumption
head(all_data)

## all data may be split into payments and consumption.  start with consumption:
consumption <- all_data[-which(rowSums(all_data[c("Coffee","Tea")])==0),]
consumption <- consumption[!names(consumption)%in%c("Payment","Payment.Date")]
## names to numbers -- are numbers unique?  
## may have to delete rows in person database

## destroy 'milk/nomilk' column:
## how many milk drinkers drank tea?
## we COULD simply go Tea+Coffee*Milk
## BUT
## milk was not always charged for!
## when did we start charging!?!
milk_charge_date <- ymd(info$Date[which.min(is.na(info$CostMilk))])
## make a new vector, milkmoney, which will be 0 until this date and then 1 or 0 afterwards, depending on the person
milkmoney <- consumption$Milk

coop_dates <- ymd(as.character(consumption$data_date))
consumption$Milkconsumed <- with(consumption,Tea+Coffee*Milk*(coop_dates>milk_charge_date))
consumption <- consumption[!names(consumption)%in%c("Name","Milk","Tea")]
# awkwardly change the 'Milkconsumed' column back
names(consumption)[which(names(consumption)=="Milkconsumed")] <- "Milk"

head(consumption)

## Now for payment info

## payments of CASH into the coop
payments <- all_data[-which(all_data$Payment==0),]
payments <- payments[!names(payments)%in%c("Name","Milk","Coffee","Tea")]

head(payments)
## note: it is confusing that there are two datelike columns: data_date and Payment.Date
## data_date = the date on which the sheet was made up
## Payment.Date = the date on which the person paid

## how are the other spreadsheets?
info
info <- info[!names(info)%in%c("Cash","Assets","MilkOutgoing")]
head(info)


people
## this one is tricky.  under the new system we have no need for the 'Name' column; all others can stay
people <- people[!names(people)%in%"Name"]
## which IDs are duplicated?
duplicates <- names(which(table(people$ID)==2))
duplicate_ppl <- people[people$ID%in%duplicates,]
head(duplicate_ppl)
rownames(duplicate_ppl) <- NULL

## first let's split by ID and see what is identical:
duplicate_list <- split(duplicate_ppl,duplicate_ppl$ID)
allidentical <- function(listelement) all(sapply(listelement,function(x) identical(x[1],x[2])))
both_same <- sapply(duplicate_list,FUN=allidentical)
## both_same have the same entries for each variable, and one row may be deleted safely
## the others are more problematic:
duplicate_list[!both_same]
## many cases of NA -- just make them the same!
nareplace <- function(listelement ) {
  out <- lapply(listelement,function(x){
    if(sum(x=="NA")==1){
      x[x!="NA"]
    }
    else x[1]
  }
  )
  data.frame(out)
}
same_combined <- do.call(rbind,lapply(duplicate_list[!both_same],nareplace))
##  these are a mess! many people are listed as 'gone', because we had to imagine a fake person disappeared.
ids_maybe_gone <- same_combined[same_combined$Gone,][["ID"]]
duplicate_ppl[duplicate_ppl$ID%in%ids_maybe_gone,]
## not.gone == Alathea, Jeremy, Simone
same_combined[same_combined$ID%in%c(6,114,226),"Gone"] <- FALSE
same_combined
## looks good. 
## take only one of the true duplicates
one_each_duplicate <- lapply(duplicate_list[both_same],"[",i=1,j=)

one_each_duplicate_df <- do.call(rbind,one_each_duplicate)
people_nodoubles <- rbind(one_each_duplicate_df,same_combined,people[!people$ID%in%duplicates,])
## there is, however, a TRIPLE: Anna Goncalves, person 14
## people_nodoubles[which(people_nodoubles$ID==14),] 
## let's keep the 3rd line of her data:
people_corrected <- people_nodoubles[-which(people_nodoubles$ID==14)[c(1,2)],]

write.csv(info,file="coffee_database/info.csv",row.names=FALSE)
write.csv(people_corrected,file="coffee_database/people.csv",row.names=FALSE)
write.csv(payments,file="coffee_database/payments.csv",row.names=FALSE)
write.csv(consumption,file="coffee_database/consumption.csv",row.names=FALSE)
