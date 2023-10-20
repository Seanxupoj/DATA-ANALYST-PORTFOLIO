# Loading packages used for this analysis
library(tidyverse)
library(janitor)

# Importing files and assigning data names
activity <- read_csv("dailyActivity_merged.csv")
h_steps <- read_csv("hourlySteps_merged.csv")
sleep <- read_csv("sleepDay_merged.csv")
weight <- read_csv("weightLogInfo_merged.csv")

# Reviewing imported data frames
head(activity)
glimpse(activity)

head(h_steps)
glimpse(h_steps)

head(sleep)
glimpse(sleep)

head(weight)
glimpse(weight)

# Verifying the number of unique user IDs in each data frame
n_distinct(activity$Id)
n_distinct(h_steps$Id)
n_distinct(sleep$Id)
n_distinct(weight$Id)

# Identifying the number of duplicate rows in data frames
sum(duplicated(activity))
sum(duplicated(h_steps))
sum(duplicated(sleep))

# Removing duplicate rows in sleep data frames
sleep <- unique(sleep)
sum(duplicated(sleep))

# Cleaning and renaming columns in data frames
clean_names(activity)
activity <- rename_with(activity, tolower)

clean_names(sleep)
sleep <- rename_with(sleep, tolower)

clean_names(h_steps)
h_steps <- rename_with(h_steps, tolower)

# Converting date and time format and rename columns for merging
activity <- activity %>% 
  rename(date = activitydate) %>%
  mutate(date = as_date(date, format = "%m/%d/%Y"))
sleep <- sleep %>%
  rename(date = sleepday) %>%
  mutate(date = as_date(date, format = "%m/%d/%Y  %I:%M:%S %p"))

#============= old code with tz
#activity <- activity %>% 
  #rename(date = activitydate) %>%
  #mutate(date = as_date(date, format = "%m/%d/%Y"))
#sleep <- sleep %>%
  #rename(date = sleepday) %>%
  #mutate(date = as_date(date, format = "%m/%d/%Y  %I:%M:%S %p", tz = Sys.timezone()))
#=============

# Converting date string to date and time format and rename the column
h_steps <- h_steps %>% 
  rename(date_time = activityhour) %>% 
  mutate(date_time = as.POSIXct(date_time, format="%m/%d/%Y %I:%M:%S %p"))
head(h_steps)

#============== old code with tz
#h_steps <- h_steps %>% 
  #rename(date_time = activityhour) %>% 
  #mutate(date_time = as.POSIXct(date_time, format="%m/%d/%Y %I:%M:%S %p", tz= Sys.timezone()))
#==============

# Merging activity and sleep into a new data frame called activity_sleep
activity_sleep <- merge(activity, sleep, by= c("id","date"), all.x = TRUE) 
head(activity_sleep)

# Summarizing the newly merged activity_sleep data
activity_sleep %>% 
  select(totalsteps, calories, veryactiveminutes, fairlyactiveminutes, 
         lightlyactiveminutes, sedentaryminutes, totalsleeprecords, 
         totalminutesasleep, totaltimeinbed) %>% 
  drop_na() %>% 
  summary() 
# Findings
## 16hrs of light active + sedentary + in bed no sleep (70 % of the day)
## average of 8515 steps per day (lower than 10k recommended by CDC)
## average sleep of 6.98hrs per day

# Find correlations between daily steps, calories, and sleep with scatter plots
ggplot(data = activity_sleep, aes(x = totalsteps, y = calories))+
  geom_point(alpha = 0.4)+
  geom_smooth(size = 0.8, color = "green3")+
  labs(title = "Correlation: Daily Steps vs Calories Loss", 
       x = "Daily Steps", y = "Calories Loss")+
  theme_gray()
 ## steps and calories = positive correlation

ggplot(data = subset(activity_sleep, !is.na(totalminutesasleep)), 
                     aes(x = totalsteps, y = totalminutesasleep))+
  geom_point(alpha = 0.4)+
  geom_smooth(size = 0.8, color = "green3")+
  labs(title = "Correlation: Daily Steps vs Sleep", 
       x = "Daily Steps", y = "Sleep")+
  theme_gray()
 ## steps and sleep = no correlation

# Separate data_time column into date and time in h_steps data frame
h_steps <- h_steps %>% 
  separate(date_time, into = c("date", "time"), sep = " ") %>% 
  mutate(date = ymd(date))

# add a new data frame with weekday and average steps columns
h_steps_weekday <- (h_steps) %>%
  mutate(weekday = weekdays(date)) %>%
  group_by(weekday, time) %>% 
  summarize(average_steps = mean(steptotal), .groups = 'drop')

h_steps_weekday$weekday <- ordered(h_steps_weekday$weekday, 
                                  levels = c("Monday", "Tuesday", "Wednesday","Thursday",
                                           "Friday", "Saturday", "Sunday"))

# Find out average activity level during the days of the week with a heat map
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
 ## Users start their day later on weekends, 
 ## and are most active during 11am-1pm on Saturday, and 5-6pm on Wednesday.

# Grouping users into four types based on average steps.
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

# Grouping user_type and calculating the proportion of total.
user_type_sum <- daily_average %>% 
  group_by(user_type) %>% 
  summarize(total = n()) %>% 
  mutate(total_proportion = total/sum(total))
View(user_type_sum)
## can create pie chart for this in excel.

# Identifying the usage level of wellness tracker.
days_usage <- activity_sleep %>% 
  group_by(id) %>% 
  summarize(usage_days = n()) %>% 
  mutate(usage_level = case_when(
    usage_days >= 1 & usage_days <= 10 ~ "Low", 
    usage_days >= 11 & usage_days <= 20 ~ "Midium",
    usage_days >= 21 & usage_days <= 31 ~ "High",
  ))

# Grouping usage_level and calculating the proportion of total.
usage_level_sum <- days_usage %>% 
  group_by(usage_level) %>% 
  summarize(user_count = n()) %>% 
  mutate(total_proportion = user_count/sum(user_count))
View(usage_level_sum)
## can create pie chart for this in excel.
## 87% of users recorded their daily activity for over 25 days.

# Calculating average hourly steps throughout the day and creating a bar graph.
avg_h_steps <- h_steps %>% 
  group_by(time) %>% 
  summarize(avg_steps = mean(steptotal))

ggplot(data = avg_h_steps)+
  geom_col(mapping = aes(x = time, y = avg_steps, fill = avg_steps))+ 
  labs(title = "Average Hourly Steps Throughout the Day", x="", y="")+ 
  scale_fill_gradient(low = "yellow2", high = "green2")+
  theme(axis.text.x = element_text(angle = 90))
## Users are more active between 8am and 7pm.
## Walk more steps during lunch time from 12pm to 2pm and evenings from 5pm and 7pm.
  
