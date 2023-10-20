---
title: "Wellness Tracker Data Analysis"
author: "Supoj Xu (Sean)"
date: "2023-09-15"
output:
  html_document: default
  pdf_document: default
  word_document: default
---

```{r global_options}
knitr::opts_chunk$set(fig.path='Figs/')
```
  
  
  
## Project Overview

This exploratory analysis is a part of **Google Data Analytics Professional Certificate** as one of the options for capstone project. I selected this topic mainly because of my personal interest in healthy lifestyle. I'm using RStudio for the entire analysis and R Markdown for reporting the steps taken and the results.   

The dataset I will be analyzing is called `Fitbit fitness tracker data` from a publicly accessible source. There are 18 CSV files which contains fitness data of users assigned with unique IDs. Many files contain overlapping data; thus, I chose the 4 main CSV files to work on.

The main **objective** is to analyze smart device fitness data in order to identify trends in customer's health, behavior and smart device usage.

For readability, I have divided this project into **4 phases** as follow:  

- **Phase 1**: Reviewing data. 

- **Phase 2**: Cleaning data. 

- **Phase 3**: Analyzing and visualizing data. 

- **Phase 4**: Sharing insights from the analysis       
    
    
Let's get started!        
    
    
## Phase 1: Understanding data
  
  
### 1.1 Loading packages used in this analysis

I will use *janitor* and *tidyverse* library which comprises of packages such as *dplyr, readr, tidyr, ggplot2,* and *lubridate* for reading files, cleaning data, formating datetime, conducting analysis, creating charts, etc.   
```{r}
library(tidyverse)
library(janitor)
```


### 1.2 Importing data files and assigning data names

As I have already downloaded the files locally, we can go ahead and read each file into an object using `read_csv()`.
```{r}
activity <- read_csv("dailyActivity_merged.csv")
h_steps <- read_csv("hourlySteps_merged.csv")
sleep <- read_csv("sleepDay_merged.csv")
weight <- read_csv("weightLogInfo_merged.csv")
```


### 1.3 Reviewing the imported data frames

Now that the data is in here, we will review it to understand a bit more about what we are dealing with.
```{r}
head(activity)
glimpse(activity)

head(h_steps)
glimpse(h_steps)

head(sleep)
glimpse(sleep)

head(weight)
glimpse(weight)
```
We can see the number of rows & columns, column names, data types, and sample data for each data table above. Here is a quick observation:  

- `activity` table contains users' steps taken, distance traveled, intensity levels, and calories loss.  

- `h_steps` table contains users' hourly steps taken.  

- `sleep` table contains daily sleep logs of users including Total count of sleeps/day, Total minutes, Total Time in Bed.

- `weight` table contains weight by day in Kg and Lbs.

### 1.4 Verifying unique user IDs in each data frame
Here we need to check how many unique IDs were recorded in each table.
```{r}
n_distinct(activity$Id)
n_distinct(h_steps$Id)
n_distinct(sleep$Id)
n_distinct(weight$Id)
```
Most tables contain data of **24-33** unique IDs, except `weight` log table which only contain **8** unique IDs. Here we will drop `weight` table due to low sample size.

  
## Phase 2: Cleaning data
  
  
### 2.1 Identifying duplicate rows in data frames and removing them
To prevent inaccurate results, we need to find and remove duplicates in the data frames.
```{r}
sum(duplicated(activity))
sum(duplicated(h_steps))
sum(duplicated(sleep))
```
There are 3 duplicated rows in `sleep` table which we need to remove.

```{r}
sleep <- unique(sleep)
sum(duplicated(sleep))
```
Double check to see if the duplicated rows are removed and we can see here that they are all gone.

### 2.2 Cleaning and renaming columns in each data frame
We will use `clean_names()` function to make sure that column names are unique and only contain numbers, letters, "_", and nothing else. Also, we will change all names to lowercase for naming consistency.
```{r}
clean_names(activity)
 activity <- rename_with(activity, tolower)

clean_names(sleep)
 sleep <- rename_with(sleep, tolower)

clean_names(h_steps)
 h_steps <- rename_with(h_steps, tolower)
```


### 2.3 Converting date and time formats, and renaming columns

We will rename date columns for easy understanding and change the data types from `chr` to `date` with `mutate()`.
```{r}
activity <- activity %>% 
  rename(date = activitydate) %>%
  mutate(date = as_date(date, format = "%m/%d/%Y"))

sleep <- sleep %>%
  rename(date = sleepday) %>%
  mutate(date = as_date(date, format = "%m/%d/%Y  %I:%M:%S %p"))

h_steps <- h_steps %>% 
  rename(date_time = activityhour) %>% 
  mutate(date_time = as.POSIXct(date_time, format="%m/%d/%Y %I:%M:%S %p"))
```



### 2.4 Merging two data frames into a new one

We will merge `activity` and `sleep` tables together for upcoming analysis.
```{r}
activity_sleep <- merge(activity, sleep, by = c("id","date"), 
                        all.x = TRUE) 
head(activity_sleep)
```

  
  
## Phase 3: Analyzing and visualizing data
  
  
### 3.1 Calculating statistical values for the newly merged data frame

Now that we have a merged table, we can select particular columns and calculate basic statistics for quick insights using `summary()`.  
```{r}
activity_sleep %>% 
  select(totalsteps, calories, veryactiveminutes, fairlyactiveminutes, 
         lightlyactiveminutes, sedentaryminutes, totalsleeprecords, 
         totalminutesasleep, totaltimeinbed) %>% 
  drop_na() %>% 
  summary() 
```
Here are some insights we can draw from these numbers:
- 

### 3.2 Finding correlations between variables with scatter plots

We will use scatter plot to understand the relationships between variables like **steps taken**, **calories**, and **sleep duration**
```{r}
ggplot(data = activity_sleep, aes(x = totalsteps, y = calories))+
  geom_point(alpha = 0.4)+
  geom_smooth(size = 0.8, color = "green3")+
  labs(title = "Correlation: Daily Steps vs Calories Loss", 
       x = "Daily Steps", y = "Calories Loss")+
  theme_gray()
```
The correlation between **steps** and **calories loss**


```{r}
ggplot(data = subset(activity_sleep, !is.na(totalminutesasleep)), 
                     aes(x = totalsteps, y = totalminutesasleep))+
  geom_point(alpha = 0.4)+
  geom_smooth(size = 0.8, color = "green3")+
  labs(title = "Correlation: Daily Steps vs Sleep Duration", 
       x = "Daily Steps", y = "Sleep Duration")+
  theme_gray()
```
The correlation between **steps** and **sleep duration**


#### 3.3 Separating data_time column into date and time in h_steps data frame
```{r}
h_steps <- h_steps %>% 
  separate(date_time, into = c("date", "time"), sep = " ") %>% 
  mutate(date = ymd (date))
```


#### 3.4 Adding a new data frame aggregating average steps by weekday and time
```{r}
h_steps_weekday <- (h_steps) %>%
  mutate(weekday = weekdays(date)) %>%
  group_by(weekday, time) %>% 
  summarize(average_steps = mean(steptotal), .groups = 'drop')

h_steps_weekday$weekday <- ordered(h_steps_weekday$weekday, 
                                  levels = c("Monday", "Tuesday", 
                                           "Wednesday","Thursday",
                                           "Friday", "Saturday", 
                                           "Sunday"))
```


#### 3.5 Visualizaing average activity level during the days of the week with a heat map
```{r}
ggplot(h_steps_weekday, aes(x= time, y= weekday, 
                           fill= average_steps)) +
  theme(axis.text.x = element_text(angle = 90))+
  labs(title = "Active Time During the Week", 
       x = " ", y = " ", fill = "average\nsteps",
       caption = 'Data Source: Fitabase Data')+
  scale_fill_gradient(low = "white", high ="green3")+
  geom_tile(color = "white",lwd =.6,linetype =1)+
  coord_fixed()+
  theme(plot.title = element_text(hjust = 0.5, vjust = 0.8, size = 15),
        panel.background = element_blank())
```


#### 3.6 Grouping users into four types
```{r}
daily_average <- activity_sleep %>%
  group_by(id) %>% 
  summarize(avg_steps = mean(totalsteps), avg_calories = mean(calories), 
            avg_sleep = mean(totalminutesasleep, na.rm = TRUE)) %>% 
  mutate(user_type = case_when(
    avg_steps < 5000 ~ "Sedentary",
    avg_steps >= 5000 & avg_steps < 7499 ~ "Lightly active", 
    avg_steps >= 7499 & avg_steps < 9999 ~ "Fairly active", 
    avg_steps >= 9999 ~ "Very active"
  ))
```

Calculating total proportion value of each user type
```{r}
user_type_sum <- daily_average %>% 
  group_by(user_type) %>% 
  summarize(total = n()) %>% 
  mutate(total_proportion = total/sum(total))

user_type_sum
```


#### 3.7 Categorizing users by the usage level of wellness tracker
```{r}
days_usage <- activity_sleep %>% 
  group_by(id) %>% 
  summarize(usage_days = n()) %>% 
  mutate(usage_level = case_when(
    usage_days >= 1 & usage_days <= 10 ~ "Low", 
    usage_days >= 11 & usage_days <= 20 ~ "Midium",
    usage_days >= 21 & usage_days <= 31 ~ "High",
  ))
```

Calculating total proportion value of each usage level
```{r}
usage_level_sum <- days_usage %>% 
  group_by(usage_level) %>% 
  summarize(user_count = n()) %>% 
  mutate(total_proportion = user_count/sum(user_count))

usage_level_sum
```


#### 3.8 Finding average hourly steps throughout the day and visualizing the values
```{r}
avg_h_steps <- h_steps %>% 
  group_by(time) %>% 
  summarize(avg_steps = mean(steptotal))
```

Visualizing with a colored bar graph
```{r}
ggplot(data = avg_h_steps)+
  geom_col(mapping = aes(x = time, y = avg_steps, fill = avg_steps))+ 
  labs(title = "Average Hourly Steps Throughout the Day", x="", y="")+ 
  scale_fill_gradient(low = "yellow3", high = "green3")+
  theme(axis.text.x = element_text(angle = 90))
```

  
  
## Phase 4: Sharing insights from the analysis
  
**Key findings**:  

- a. 

- b. 

- c.  

- It is important to note that this dataset was collected in 2016 before the pandemic which might have already shifted people’s behavior. More up-to-date data would be required to generate more accurate insights for today’s consumers.


