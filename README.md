# SERIMI – Resource Description Similarity, RDF Instance Matching and Interlinking  

![](https://github.com/samuraraujo/SERIMI-RDF-Interlinking/raw/master/image.png)
   
The interlinking of datasets published in the Linked Data Cloud is a 
challenging problem and a key factor for the success of the Semantic Web. 
Manual rule-based methods are the most effective solution for the problem, but 
they require skilled human data publishers going through a laborious, error 
prone and time-consuming process for manually describing rules mapping 
instances between two datasets. Thus, an automatic approach for solving this 
problem is more than welcome. We propose a novel interlinking 
method, SERIMI, for solving this problem automatically. SERIMI matches 
instances between a source and a target datasets, without prior knowledge of the 
data, domain or schema of these datasets. Experiments conducted with 
benchmark collections demonstrate that our approach considerably outperforms 
state-of-the-art automatic approaches for solving the interlinking problem on 
the Linked Data Cloud. 

In this repository you encounter the SERIMI interlinking script. 

You also encounter the reference alignment for Dailymed-TCM that we fixed.

# Requirements 

### 1. Data repository 
Serimi ONLY works over Virtuoso Openlink server ([download here](http://sourceforge.net/projects/virtuoso/files/)) Sparql Endpoints. Therefore, you need to provide to Serimi, as target for the interlinking, a Virtuoso Sparql endpoint.

How To Load RDF Data into Virtuoso?

If you want to try Serimi over you own data, you have to load your data into a Virtuoso server. Below we show how to do it.

This example assumes that you are loading the Geonames into Virtuoso.  

Notice that virtuoso does not have a unique repository for each dataset. It has just a repository and it organizes the datasets in different NAMED GRAPHS. The example below loads the data into the http://geonames.org Named Graph.

ALL COMMANDS ARE COMPULSORIES

	checkpoint_interval(-1);
	DB.DBA.RDF_OBJ_FT_RULE_ADD (null, null, 'index_local');
	DB.DBA.VT_INC_INDEX_DB_DBA_RDF_OBJ ();	
	CREATE BITMAP index RDF_QUAD_POGS on DB.DBA.RDF_QUAD (P,O,G,S);
	CREATE BITMAP index RDF_QUAD_PSOG on DB.DBA.RDF_QUAD (P,S,O,G);
	CREATE BITMAP index RDF_QUAD_SOPG on DB.DBA.RDF_QUAD (S,O,P,G);	
	//For RDF format
	DB.DBA.RDF_LOAD_RDFXML_MT (file_to_string_output ('/tmp/all-geonames.rdf'), '', 'http://geonames.org');	
	//For NT format
	DB.DBA.TTLP_MT (file_to_string_output ('/tmp/all-geonames.ttl'), '','http://geonames.org');
	checkpoint;
	checkpoint_interval(30);

### 2. JRuby

Serimi is a Ruby application and demands the Jruby version of ruby. We recommend to install JRuby using the [RVM](https://rvm.beginrescueend.com/).

### 3. Gems

After install JRuby, you have to install the following gems in order to make Serimi works properly:

* actionmailer (2.3.2)
* actionpack (2.3.2)
* activerecord (2.3.2)
* activeresource (2.3.2)
* activesupport (2.3.2)
* amatch (0.2.5)
* bouncy-castle-java (1.5.0146.1)
* elasticsearch (0.0.0)
* jruby-launcher (1.0.7 java)
* jruby-openssl (0.7.4)
* json (1.5.1 java)
* OptionParser (0.5.1)
* patron (0.4.9)
* rails (2.3.2)
* rake (0.8.7)
* sources (0.0.1)
* Text (1.1.2)
* text (0.2.0)
* uuidtools (1.0.7)
* xml-object (0.9.93)
* yajl-ruby (0.8.2)

<b>IMPORTANT:</b>
You MUST install the uuidtools version 1.0.7

	gem install uuidtools -v=1.0.7

## Installation

You can download the source code of SERIMI using the Git command below. For that you need to install the Git in your computer.

	git clone git://github.com/samuraraujo/SERIMI-RDF-Interlinking.git
 
You can also download it by clicking in the button DOWNLOADS on the top of this page.

## Testing the installation

Go to the root of the directory where you executed the command above and type:

	ruby serimi.rb

If everything is fine, this command will print help information about Serimi. Below you find information about how to use Serimi.
 
## Usage

Usage: serimi.rb [options] 

Example of use: 

	ruby serimi.rb -s http://localhost:8890/sparql -t http://dbpedia.org/sparql?default-graph-uri=http://dbpedia.org -c http://www.semwebtech.org/mondial/10/meta#Country 
	
In the example above, the source is a local endpoint, the target is the DBPedia endpoint , and the source class to be interlinked is the class country.

Parameters

	-v, --verbose                    Output more information
	-s, --source SPARQL_URI          Source Virtuoso sparql endpoint - URI
	-t, --target SPARQL_URI          Target Virtuoso sparql endpoint - URI
	-c, --class URI                  Source class for interlink - URI
	-o, --output FILE                Write output to FILE - Default=./output.txt
	-f, --output-format value        Output format: txt or nt. Default=txt
	-k, --chunk value                Chunk size - Default=20
	-b, --offset value               Start processing from a specific offset - Default=0
	-x, --string-threshold value     String distance threshold. A value between (0,1) - Default=0.7
	-y, --rds-threshold value        RDS threshold. A value between (0,1) - Default=max(media,mean)
	-l, --logfile FILE               Write log to FILE
	-h, --help                       Display this screen

### Advanced use

You can change the value of thresholds used in Serimi. The are two parameters for this:

-x: allow you to define a threshold for the string distance function applied in Serimi. Serimi selects labels of the sources resources and search for these labels in the target endpoint. This parameter defines how similar the retrieved resources should be with regards to the searched label. You can define a value between (0,1)

-y: allow you to define a threshold for the RDS function implemented in Serimi. Currently the value for this parameter is computed automatically. You can force a specific value for this parameter. You can define a value between (0,1).

### Output

Serimi outputs the interlinks in external file. It accept two output format (text or nt). You configure the output format using -f parameter.

## Issues

To report any issue about this tool you can use this system: https://github.com/samuraraujo/SERIMI-RDF-Interlinking/issues
