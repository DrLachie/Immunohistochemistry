/* 
 *  Moritz_DAB_Measure.ijm
 *  Measure DAB stained area of aperio images.
 *  
 *  Written for Moritz Eissmann
 *  Code by Lachlan Whitehead (whitehead@wehi.edu.au)
 *  Feb 2014
 *  
 */


/* 
 *  Detailed description
 *  Measure DAB stained area of aperio images. Does basic segmentation using colour 
 *  deconvolution and thresholding. Threshold can be manually adjusted by selecting 
 *  the option in the menu (selected by default). Also generates jpg masks if required.
 *  Use preferred selection tool to define region to be measured.
 *  
 *  Either run on an open image, or run with nothing open to batch a directory. 
 *      
 */


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//Set up variables (add any that are needed dir1,dir2,list, and fs are all required by functions);
var dir1="C:\\";
var dir2="C:\\";
var list = newArray();
var fs = File.separator();

var GENERATE_MASKS = true;
var MANUAL_THRESHOLD = true;
var PIXEL_SCALE = 0.5;
var DRAW_ROI = true;
var SELECTION_TOOL = "polygon";
var COLOUR_METHOD = "H DAB";

if(isOpen("ROI Manager")){
	selectWindow("ROI Manager");
	run("Close");
}


//Channel sorting - based on colour deconvolution method
//Blue - normal tissue 
//Brown - stained tissue 	
if(COLOUR_METHOD == "H DAB"){
	BLUE_IMAGE = "-(Colour_1)";
	BROWN_IMAGE = "-(Colour_2)";
	UNUSED_IMAGE = "-(Colour_3)";
}







//Setup custom results table 
Table_Heading = "DAB Measure";
columns = newArray("Filename","Whole Tissue Area", "Stained Area", "% Coverage");
table = generateTable(Table_Heading,columns);

OptionsMenu();

//Batch a directory?
batchFlag = Batch_Or_Not();

//Begin the thing!
for(i=0;i<list.length;i++){
	
	//If we're batching, and it's not a directory, open the next file (This was one if statement, but works better separately
	if(!File.isDirectory(dir1+list[i])){
		if(batchFlag){
			IJ.redirectErrorMessages(); 	//in case of bad image
			open(dir1+list[i]);
		}
		if(nImages>0){				//in case of bad image
		//////////////////////
		//Do things in here //
		//////////////////////
		fname = list[i];
		run("Set Measurements...", "area limit redirect=None decimal=3");
		run("Properties...", "channels=1 slices=1 frames=1 unit=micron pixel_width="+PIXEL_SCALE+" pixel_height="+PIXEL_SCALE+" voxel_depth="+PIXEL_SCALE+" frame=[0 sec] origin=0,0 global");
		fname = getTitle();
		run("ROI Manager...");
		if(DRAW_ROI){	
			setTool(SELECTION_TOOL);
	
			if(SELECTION_TOOL=="freehand"){
				waitForUser("Draw ROI for measurement. \n\nThen press OK");
			}else{
				waitForUser("Draw ROI for measurement. \n\nDouble click to end line.\n\nThen press OK");
			}
		}else{
			run("Select All");
		}
		roiManager("Add");
		roiManager("Deselect");
		roiManager("Show All");
		roiManager("Show None");
		
		
		run("Duplicate...", "title=whole_tissue");
		run("8-bit");
		setOption("BlackBackground", true);
		setAutoThreshold("Intermodes");
		run("Convert to Mask");
		//run("Fill Holes");
		roiManager("Select",0);
		setThreshold(1,255);
		run("Measure");
		whole_tissue_area = getResult("Area",nResults-1);
		
		selectWindow(fname);
		run("Colour Deconvolution", "vectors=[H DAB] hide");
		close(fname+"-(Colour_3)");
		selectWindow(fname+"-(Colour_2)");
		run("Subtract Background...", "rolling=50 light");
		run("Smooth");
		setAutoThreshold("Default");
		run("Threshold...");
		if(MANUAL_THRESHOLD){
			waitForUser("Adjust threshold as needed.\n\nThen press OK");
		}
		roiManager("Select",0);
		run("Measure");
		stained_area = getResult("Area",nResults-1);
		percent_coverage = 100.0 * stained_area / whole_tissue_area;
		
		setOption("BlackBackground", true);
		run("Convert to Mask");
		close(fname+"-(Colour_3)");
		close(fname+"-(Colour_1)");
		if(GENERATE_MASKS){
			run("Merge Channels...", "c1="+fname+"-(Colour_2) c3=whole_tissue create ignore");
			run("RGB Color");
			if(DRAW_ROI){
				roiManager("Show All");
				roiManager("Select",0);
				
				run("Make Inverse");
				run("Smooth");
							
				run("Gaussian Blur...", "sigma=10");
			
				roiManager("Show All");
				roiManager("Show All without labels");
				roiManager("Set Color", "yellow");
				roiManager("Set Line Width", 10);
			}
			run("Flatten");
					
			saveAs("JPG",dir2+substring(fname,0,lengthOf(fname)-4)+"_mask.jpg");
		}

		selectWindow("ROI Manager");
		run("Close");

		//Put the results in this array
		resultArray = newArray(fname,whole_tissue_area,stained_area,percent_coverage);
				
		//Log the results into the table
		logResults(table,resultArray);
	
		//Clean up only if we're batching, if not just leave everything open
		//Consider closing superflous images as you go along
		if(batchFlag){
			run("Close All");
		}}
	}
}

//Save results table?
selectWindow(Table_Heading);
if(batchFlag){
	saveTable(Table_Heading);
}


////////////////////////////////////////////////////
// Functions 					  //
////////////////////////////////////////////////////

//Choose what to batch on
function Batch_Or_Not(){
	// If an image is open, run on that
	if(nImages == 1){
		fname = getInfo("image.filename");
		dir1 = getInfo("image.directory");
		dir2 = dir1 + "output" + fs;
		list=newArray("temp");
		list[0] = fname;
		batchFlag = false;
	// If more than one is, choose one
	}else if(nImages > 1){
		waitForUser("Select which image you want to run on");
		fname = getInfo("image.filename");
		dir1 = getInfo("image.directory");
		dir2 = dir1 + "output" + fs;
		list=newArray("temp");
		list[0] = fname;
		batchFlag = false;	
	// If nothing is open, batch a directory
	}else{
		dir1 = getDirectory("Select source directory");
		list= getFileList(dir1);
		dir2 = dir1 + "output" + fs;
		batchFlag = true;
	}

	if(!File.exists(dir2)){
		File.makeDirectory(dir2);
	}
	return(batchFlag);
}

//Choose a random LUT - not really useful but you never know
function RandomLUT(){
	lut_list = getList("LUTs");
	lut = lut_list[round(random() * (lut_list.length-1))];
	return lut;	
}

//Generate a random color using the current LUT
function RandomColour(){
	getLut(reds,greens,blues);
	a = round(random()*255);
	r = toHex(reds[a]);
	if(lengthOf(r)==1){r = "0"+r;}
	g = toHex(greens[a]);
	if(lengthOf(g)==1){g="0"+g;}	
	b = toHex(blues[a]);
	if(lengthOf(b)==1){b="0"+b;}
	color = r+g+b;
	return color;
}

//Get a specific colour from the current LUT
function getColour(index){
	getLut(reds,greens,blues);
	a = index;
	r = toHex(reds[a]);
	if(lengthOf(r)==1){r = "0"+r;}
	g = toHex(greens[a]);
	if(lengthOf(g)==1){g="0"+g;}
	b = toHex(blues[a]);
	if(lengthOf(b)==1){b="0"+b;}
	color = r+g+b;
	return color;
}

function OptionsMenu(){

	/* HELP for options menu */
  	  help = "<html>"
	     +"<h3>Macro help</h3>"
	     +"<A HREF=\"mailto:whitehead@wehi.edu.au\">whitehead@wehi.edu.au</A>"
	     +"<BR><HR><BR>"
	     +"Run on an open image, or run with nothing open to batch a directory<BR>"
	     +"<h3> Options </h3><BR>"
	     +"<h4>\"Generate Masks\"</h4>"
	     +"		Generate and save binary masks showing exactly what has been measured.<BR><BR>"
	     +"<h4>\"Allow manual adjustment of threshold\"</h4>"
	     +"		 When thresholding stained areas, allow user to manually adjust threshold values.<BR>"
	     +"		 True by default.<BR><BR>"
	     +"<h4>\"Pixel scaling\"</h4>"
	     +"		 Set the scale of the image. Aperio images taken at 20x (default) and extracted <BR>"
	     +"          at full resolution have a pixel scale of 0.5um/pixel.<BR><BR>"
	     +"<h4>\"Draw ROI?\"</h4>"
	     +"		 Allows user to define a section of the image to analyse, if unselected. <BR>"
	     +"          will simply analyse the entire image.<BR><BR>"
	     +"<h4>\"Preferred Selection Tool\"</h4>"
	     +"		 Either polygon or freehand. <BR>"
	     +"          Polygon - click between straight line sections<BR>"
	     +"          Freehand - click and hold to create region.<BR><BR>"
	     +"<h4>\"Colour Separation Method\"</h4>"
	     +"		 Currently unused option. <BR>"
	     +"          Will allow alternative colour deconvolution matrices.<BR><BR>"
	     +"</font></HTML>";

	
	
  	Dialog.create("Options Menu for Macro");
 	
	Dialog.addMessage("Options:");
  	Dialog.addCheckbox("Generate Masks", true);
		//Dialog.setInsets(0, 40, 0);
  		Dialog.addCheckbox("Allow manual adjustment of threshold",true);
  		Dialog.setInsets(20, 10, 0);
  		//Dialog.addCheckbox("Checkbox3",false);
  	Dialog.addNumber("Pixel scaling",0.5,2,5,"um/pixel");
  	Dialog.setInsets(-3, 10, 0);
  	Dialog.addMessage("0.5 um/pixel for full resolution Aperio images");
  	Dialog.setInsets(20, 40, 0);
  	Dialog.addCheckbox("Draw ROI?",true);
	Dialog.addChoice("Preferred Selection Tool",newArray("polygon","freehand"),"polygon");
	Dialog.setInsets(20, 0, 0);
	Dialog.addChoice("Colour separation method",newArray("H DAB","H&E DAB"),"H DAB");
	
  	Dialog.setInsets(25, 40, 10);
  	Dialog.addMessage("Email support:\n\nwhitehead@wehi.edu.au");
	Dialog.addHelp(help);

	Dialog.show();

	//PUT THESE VARIABLES INTO GLOBAL DECLARATIONS AT THE START OF THE MACRO.
	//can return them as an array but it's less modular that way. 
	GENERATE_MASKS = Dialog.getCheckbox();
	MANUAL_THRESHOLD = Dialog.getCheckbox();
	PIXEL_SCALE = Dialog.getNumber();
	DRAW_ROI = Dialog.getCheckbox();
	SELECTION_TOOL = Dialog.getChoice();
	COLOUR_METHOD = Dialog.getChoice();
	
}


//Generate a custom table
//Give it a title and an array of headings
//Returns the name required by the logResults function
function generateTable(tableName,column_headings){
	if(isOpen(tableName)){
		selectWindow(tableName);
		run("Close");
	}
	tableTitle=tableName;
	tableTitle2="["+tableTitle+"]";
	run("Table...","name="+tableTitle2+" width=600 height=250");
	newstring = "\\Headings:"+column_headings[0];
	for(i=1;i<column_headings.length;i++){
			newstring = newstring +" \t " + column_headings[i];
	}
	print(tableTitle2,newstring);
	return tableTitle2;
}


//Log the results into the custom table
//Takes the output table name from the generateTable funciton and an array of resuts
//No checking is done to make sure the right number of columns etc. Do that yourself
function logResults(tablename,results_array){
	resultString = results_array[0]; //First column
	//Build the rest of the columns
	for(i=1;i<results_array.length;i++){
		resultString = toString(resultString + " \t " + results_array[i]);
	}
	//Populate table
	print(tablename,resultString);
}

//Save a table
function saveTable(temp_tablename){
	selectWindow(temp_tablename);
	if(File.exists(dir2+temp_tablename+".txt")){
		overwrite=getBoolean("Warning\nResult table \""+temp_tablename+"\" file alread exists, overwrite?");
			if(overwrite==1){
				saveAs("Text",dir2+temp_tablename+".txt");
			}
	}else{
		saveAs("Text",dir2+temp_tablename+".txt");
	}
}
