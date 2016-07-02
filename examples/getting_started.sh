#!/usr/bash

# This will setup the following
# bequn_tutorial/
#	sales_data/
#	top_customers/
#		total_sales/

# ----------------------------------------------------------------------
# Set up the directory

mkdir bequn_tutorial
cd bequn_tutorial

mkdir sales_data
curl bequn.com/sales_2016.csv

cd ..
mkdir top_customers
cd top_customers

# Initialize the directory to bequn, using python
bequn init python # could have been R or ipython

# look at the directory structure
ls

	
# ----------------------------------------------------------------------
# Set up a simple analysis

# Pull a data file in as a source file
bequn source ../sales_data/sales_2016.csv

# Write the analysis script
cat > analyze.py << EndOfMultilineString
import pandas as pd
sales = pd.read_csv("sources/sales_2016.csv")
sales = sales.sort_values('2016_revenue', ascending=False)
top_customers = sales.head(10).copy()
top_customers.to_csv("outputs/top_customers.csv")
top_customers.to_pickle("outputs/data.pickle")
EndOfMultilineString

# wait for user
echo "At this point, user executes script. Type [ENTER] aftere this is done. "
read wait_for_enter

# save this version with bequn
bequn save

# ----------------------------------------------------------------------
# Edit script, but have bequn execution for you

# Change script to be only the top 5 customers
cat > analyze.py << EndOfMultilineString
import pandas as pd
sales = pd.read_csv("sources/sales_2016.csv")
sales = sales.sort_values('2016_revenue', ascending=False)
top_customers = sales.head(5).copy()
top_customers.to_csv("outputs/top_customers.csv")
top_customers.to_pickle("outputs/data.pickle")
EndOfMultilineString

# this will report:
#	sources ok
#	inputs unsaved (and will list script as having changed)
#	evaluation NA
#	outputs NA
bequn status

# Evaluate the latest version
bequn run

# Save this as a named version
bequn save v2_top5

# ----------------------------------------------------------------------
# See what happens when the source data changes

# Move some files around to simulate a change to the external sales_2016.csv file
cd ../sales_data
rm sales_2016.csv
curl bequn.com/sales_2016_updated.csv
mv sales_2016_updated.csv sales_2016.csv
cd ../top_customers

# this will report
#   source unsynced
bequn status

# evaluate this new version
# by default, this will update the source automatically
bequn run

bequn save v3_new_data


# ----------------------------------------------------------------------
# Dealing with old versions

# lists versions that are available
bequn version

# shows info for a particular version
bequn version 1

# create copies of old versions
bequn copy 1
bequn copy v2_top5

# revert to old verions
bequn revert 1
cat outputs/top_customers.csv

# revert back to latest
bequn revert --last
cat outputs/top_customers.csv

# ----------------------------------------------------------------------
# Creating a child node

# Create the child node
bequn child total_sales

cat > analyze.py << EndOfMultilineString
import pandas as pd
sales = pd.read_pickle("sources/data.pickle")
open("outputs/report.txt") as f:
	writeline("For top customers, total sales were {}".format(sales.2016_revenue.sum()))
EndOfMultilineString

# Evaluate
bequn run

# Make a change to the script in the parent node
# Edit top_customers/analyze.R to include the top 20 customers
cat > ../analyze.py << EndOfMultilineString
import pandas as pd
sales = pd.read_csv("sources/sales_2016.csv")
sales = sales.sort_values('2016_revenue', ascending=False)
top_customers = sales.head(20).copy()
top_customers.to_csv("outputs/top_customers.csv")
top_customers.to_pickle("outputs/data.pickle")
EndOfMultilineString

# while still in top_customers/total_sales, try to re-evaluate
# it prompts the user whether to update that directory ('bequn run')
bequn run

# ----------------------------------------------------------------------
# Noticing downstream errors

# change back to parent directory, bequn_tutorial/top_customers
cd ..

# rename the revenue column to revenue_usd
cat > ../analyze.py << EndOfMultilineString
import pandas as pd
sales = pd.read_csv("sources/sales_2016.csv")
sales = sales.sort_values('2016_revenue', ascending=False)
sales = sales.rename(columns={'2016_revenue': '2016_revenue_usd'})
top_customers = sales.head(20).copy()
top_customers.to_csv("outputs/top_customers.csv")
top_customers.to_pickle("outputs/data.pickle")
EndOfMultilineString

# Evalaute, which should notify of child error
bequn run

# This wasn't any important change, so revert
bequn revert -1

# ----------------------------------------------------------------------
# Comparing outputs

bequn diff v2_top5 v3_new_data
# .RData files have binary differences
# csv have row differences

# ----------------------------------------------------------------------
# Annotating versions

# Create a text file with annotations, using the '# bequn notes' tag:
cat > my_version_notes.txt << EndOfMultilineString
# bequn notes
I changed to looking at top 20 customers per client request.
Next on my list: check that currencies are all revenue_usd
# bequn notes end
EndOfMultilineString

# Add this file as an input
bequn input my_version_notes.txt

# Save this version and view status
bequn save
bequn status


# ----------------------------------------------------------------------
# Commitment free changes

# Start a new fork
bequn fork

# Script to exclude customers under a certain amount
cat > ../analyze.py << EndOfMultilineString
import pandas as pd
sales = pd.read_csv("sources/sales_2016.csv")
sales = sales.sort_values('2016_revenue', ascending=False)
sales = sales.loc[sales.2016_revenue > 100] # filter to big customers only
top_customers = sales.head(20).copy()
top_customers.to_csv("outputs/top_customers.csv")
top_customers.to_pickle("outputs/data.pickle")
EndOfMultilineString

# save this version
bequn run
cat outputs/top_customers.csv

# Make another change, filtering to US only
cat > ../analyze.py << EndOfMultilineString
import pandas as pd
sales = pd.read_csv("sources/sales_2016.csv")
sales = sales.sort_values('2016_revenue', ascending=False)
sales = sales.loc[sales.2016_revenue > 100] # filter to big customers only
sales = sales.loc[sales.is_in_US == True]   # filter to US  customers only
top_customers = sales.head(20).copy()
top_customers.to_csv("outputs/top_customers.csv")
top_customers.to_pickle("outputs/data.pickle")
EndOfMultilineString

# save this version
bequn run
cat outputs/top_customers.csv

# if you wanted to keep these versions, you'd run:
# bequn fork --keep

# but we are going to trash all these changes since the fork, and revert
bequn fork --undo

