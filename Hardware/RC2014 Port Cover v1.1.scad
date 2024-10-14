// RC2014 Port Cover v1.0
//
// This script is based almost entirely on WALLY by TheNewHobbyist 2013. See notes below.
// It has been modified by Spencer from z80kits.com to suit the port cover panels on
// the RC2014 Blue Box Enclosure. These port covers are only onse size and  will only 
// fit one connector, so everything about multiple panels, multiple connectors and even
// large items like switches or power sockets has been stripped out.
//
// some of the code may well be redundant for only a single connector mounted in a panel
// of a fixed size. Sorry. I am sure things can be tidied up a lot.

// WALLY - Wall Plate Customizer v1.3
// by TheNewHobbyist 2013 (http://thenewhobbyist.com)
// http://www.thingiverse.com/thing:47956
//
// Most of the connectors used with this thing are panel mount connectors from
// www.DataPro.net I can't vouch for their quality but they did have easy to
// find dimensions for their products so I used them.
//
// This could be tightened up considerably but I thought I'd get it out there for people
// to experiment with before I lose my mind staring at it too long. Also this is my
// first OpenSCAD model so cut me some slack ;)
//
//  V1.0 Initial model as uploaded to Thingiverse
//  v1.1 Round holes much rounder and artifacts around the ears has been fixed
//

  //////////////////////////
 // Customizer Settings: //
//////////////////////////



//Type of port cover
1st_plate = "none";  //	["none":None, "blank":Blank Port, "keystone1":Keystone Jack, "vga":VGA Port, "hdmi":HDMI Port, "dvi":DVI-I Port, "displayport":Displayport, "cat5e":Cat5e/Cat6 Port, "usb-a":USB-A Port, "usb-b":USB-B Port, "firewire":Firewire IEEE 1394 Port, "db09":DB-09 Port, "ps2":PS2 Port, "f-type": F-Type/Coaxial Port,"svideo":S-Video Port, "stereo":Stereo Headphone Jack]

module GoAwayCustomizer() {
// This module is here to stop Customizer from picking up the variables below
}

//How big are we talkin' here?
plate_width = 1; //	[1:5]

// Bigger hole in your wall? Try this
plate_size = 0; // [0:Standard, 1:Junior-Jumbo, 2:Jumbo]
$fn=25;

  //////////////////////
 // Static Settings: //
//////////////////////

l_offset = [12];
r_offset = [12];
spacer = [0,0];
solid_plate_width = 24;

height_sizes = [42];

thickness = 3; //Port cover thickness (static)
height = 42; //Port cover height (static)
width = 22; //Port cover width (static)

positions=[height/2,height/2 - 14.25,height/2 + 14.25];

  ///////////////////
 // Hole Control: //
///////////////////

module plate1(){
	
		//translate([0,l_offset[plate_size],0]) box_screws();
		translate([positions[0],l_offset[plate_size],0]) hole(1st_plate);
			}


  /////////////////
 // SolidWorks: //
/////////////////

module plate1_solid(){
if (1st_plate == "keystone1" ) {
	translate([height/2 + 14.3,l_offset[plate_size] - 11.5,-3.9]) hole("keystone_solid");
	}
}

module portcoverblank() {
    difference () {
    union() {
        cube([height,width,thickness], center=true);
        translate([21.5,-5,0]) rotate([0,0,0]) cube ([1.001,8,thickness], center=true);
        translate([22.5,-5,0]) rotate([0,0,0]) cylinder (thickness,4,4, center=true);
        translate([-21.5,5,0]) rotate([0,0,0]) cube ([1.001,8,thickness], center=true);
        translate([-22.5,5,0]) rotate([0,0,0]) cylinder (thickness,4,4, center=true);
            }      
            translate([22.5,-5,0]) rotate([0,0,0]) cylinder (3.5,1.6,1.6, center=true);
            translate([-22.5,5,0]) rotate([0,0,0]) cylinder (3.5,1.6,1.6, center=true);
            }
}

// Hole Cutout definitions
module hole(hole_type) {

// Blank plate
	if (hole_type == "blank") { }

// VGA & DB09 plate
// VGA Fits http://www.datapro.net/products/vga-dual-panel-mount-f-f-cable.html
// DB09 Fits http://www.datapro.net/products/db9-serial-panel-mount-male-extension.html
	if (hole_type == "vga" || hole_type == "db09") {
        rotate([0,0,90]){
			translate([0,-12.5,3]) cylinder(r=1.75, h=10, center = true);
			translate([0,12.5,3]) cylinder(r=1.75, h=10, center = true);
				difference(){
					cube([10,19,13], center=true);
					translate([-5,-9.2,1]) rotate([0,0,-35.6]) cube([4.4,2.4,15], center=true);
					translate([.9,-11.2,0]) rotate([0,0,9.6]) cube([10,4.8,15], center=true);
					translate([4.6,-8.5,0]) rotate([0,0,37.2]) cube([4.4,2.4,15], center=true);
					translate([-5,9.2,1]) rotate([0,0,35.6]) cube([4.4,2.4,15], center=true);
					translate([0.9,11.2,0]) rotate([0,0,-9.6]) cube([10,4.8,15], center=true);
					translate([4.6,8.5,0]) rotate([0,0,-37.2]) cube([4.4,2.4,15], center=true);
								}
						}
                    }

// HDMI plate
// Fits http://www.datapro.net/products/hdmi-panel-mount-extension-cable.html
	if (hole_type == "hdmi") {
        rotate([0,0,90]){
		translate([0,-13,3]) cylinder(r=1.75, h=10, center = true);
		translate([0,13,3]) cylinder(r=1.75, h=10, center = true);
		translate([0,0,3]) cube([6,16,10], center=true);
							}
                        }

// DVI-I plate
// Fits http://www.datapro.net/products/dvi-i-panel-mount-extension-cable.html
	if (hole_type == "dvi") {
        rotate([0,0,90]){
		translate([0,-16,3]) cylinder(r=1.75, h=10, center = true);
		translate([0,16,3]) cylinder(r=1.75, h=10, center = true);
		translate([0,0,3]) cube([10,26,10], center=true);
							}
                        }

// DisplayPort plate
// Fits http://www.datapro.net/products/dvi-i-panel-mount-extension-cable.html
	if (hole_type == "displayport") {
        rotate([0,0,90]){
		translate([0,-13.5,3]) cylinder(r=1.75, h=10, center = true);
		translate([0,13.5,3]) cylinder(r=1.75, h=10, center = true);
		translate([0,0,0]){
			difference(){
				translate([0,0,3]) cube([7,19,10], center=true);
				translate([2.47,-9.37,3]) rotate([0,0,-54.6]) cube([3,5,14], center=true);
						}
								}
									}
                                }

// USB-A Plate
// Fits http://www.datapro.net/products/usb-panel-mount-type-a-cable.html
	if (hole_type == "usb-a") {
        rotate([0,0,90]){
		translate([0,-15,3]) cylinder(r=1.75, h=10, center = true);
		translate([0,15,3]) cylinder(r=1.75, h=10, center = true);
		translate([0,0,3]) cube([8,16,10], center=true);
							}
                        }

// USB-B Plate
// Fits http://www.datapro.net/products/usb-panel-mount-type-b-cable.html
	if (hole_type == "usb-b") {
        rotate([0,0,90]){
		translate([0,-13,3]) cylinder(r=1.75, h=10, center = true);
		translate([0,13,3]) cylinder(r=1.75, h=10, center = true);
		translate([0,0,3]) cube([11,12,10], center=true);
							}
                        }

// 1394 Firewire Plate
// Fits http://www.datapro.net/products/firewire-panel-mount-extension.html
	if (hole_type == "firewire") {
        rotate([0,0,90]){
		translate([0,-13.5,3]) cylinder(r=1.75, h=10, center = true);
		translate([0,13.5,3]) cylinder(r=1.75, h=10, center = true);
		translate([0,0,3]) cube([7,12,10], center=true);
							}
                        }

// F-Type / Cable TV Plate
// Fits http://www.datapro.net/products/f-type-panel-mounting-coupler.html
	if (hole_type == "f-type") {
		translate([0,0,3]) cylinder(r=4.7625, h=10, center=true);
							}

// Cat5e & Gat6 plate
// Cat5e Fits http://www.datapro.net/products/cat-5e-panel-mount-ethernet.html
// Cat6 Fits hhttp://www.datapro.net/products/cat-6-panel-mount-ethernet.html
	if (hole_type == "cat5e" || hole_type == "cat6") {
        rotate([0,0,90]){
		translate([0,-12.5,3]) cylinder(r=1.75, h=10, center = true);
		translate([0,12.5,3]) cylinder(r=1.75, h=10, center = true);
		translate([0,0,3]) cube([15,15,10], center=true);
		}
    }

// S-Video & PS2 plate
// S-Video Fits hhttp://www.datapro.net/products/cat-6-panel-mount-ethernet.html
// PS2 http://www.datapro.net/products/ps2-panel-mount-extension-cable.html
	if (hole_type == "svideo" || hole_type == "ps2") {
        rotate([0,0,90]){
		translate([0,-10,3]) cylinder(r=1.75, h=10, center = true);
		translate([0,10,3]) cylinder(r=1.75, h=10, center = true);
		translate([0,0,3]) cylinder(r=5, h=10, center=true);
		}
    }


// Stereo / 1/4" headphone jack coupler
// Stereo coupler Fits http://www.datapro.net/products/stereo-panel-mount-coupler.html
	if (hole_type == "stereo") {
		translate([0,0,3]) cylinder(r=2.985, h=10, center=true);
		}

//Keystone1 hole
//Hole for 1 Keystone Jack
	if (hole_type == "keystone1") {
		translate([0,0,5]) cube([16.6,15,10], center = true);
	}

//Keystone Solid
	if (hole_type == "keystone_solid") {
        
		rotate([0,0,90]) {
			difference(){
				translate([.5,0,.1]) cube([22,30.5,9.8]);
                    difference(){
                        translate([4,22.501,3.501]) rotate([45,0,0]) cube([15,3,3]); //this part makes it slightly easier to swivel in a keystone connector
                    }
					translate([4,4,0]){
						difference(){
							cube([15,22.5,10]);
							translate([-1,-0.001,3.501]) cube([17,2,6.5]);
							translate([-1,2.5,-3.40970]) rotate([45,0,0]) cube([17,2,6.5]);
							translate([-1,18.801,6.001]) cube([17,4,4]);
							translate([-1,20.5,0]) rotate([-45,0,0]) cube([17,2,6.5]);
						}
					}
				}
			}
		}
//End of module "hole"
}

  ////////////////////////
 // Number One ENGAGE: //
////////////////////////

// Rotate so it sits correctly on plate (whoops) and make upside down
rotate([0,180,90]){
// put plate at 0,0,0 for easier printing
translate([-height/2,-solid_plate_width/2,-thickness]){

	difference() {
		translate ([0,0,0]) portcoverblank();
		
		translate ([-height/2,-solid_plate_width/2,-thickness]) plate1();
			}
		union() {
		translate ([-height/2,-solid_plate_width/2,-thickness-1.5]) plate1_solid();
		}
//End Rotate
}
//End Translate
}