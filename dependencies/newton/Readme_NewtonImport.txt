Newton Game Dynamics Delphi-Headertranslation                           
 Current SDK version 2.16
                                                                        
Copyright (c) 04,05,06,09,2010
			 Stuart "Stucuk" Carey
			 Executor
			 Sascha Willems                                 
		         Jon Walton                                  
		         Dominique Louis                                
        Initial Author : S.Spasov (Sury)                                   

About :
==============================================================================================
The file "NewtonImport.pas" contains the current translation of the header for the
Newton Game Dynamics Physics SDK (http://www.newtongamedynamics.com) and should work with
Delphi and Free Pascal. Other Pascal languages might work but were not tested
(except for VP, which was tested, but VP is discontinued).

"NewtonImport_JointLibrary" contains the current translation of the joint library with
different tpyes of joints. It was initially done by Exectutor and needs the dll
"JointLibrary.dll" from the Newton SDK.


Where to get :
==============================================================================================
The current version of this header can always be downloaded at http://newton.freemapeditor.com/
and may also be available at http://newton.delphigl.de .
It's usually udpated when the SDK itself is updated, but there may also be some out-of-order
updates in case there are errors/problems with the header translation.


History (in reverse order for direct visibility of recent updates) :
==============================================================================================
  
  Changes on 04.03.2010 by Stuart Carey
   + Changed NewtonCreateCompoundCollision's array to PNewtonCollision
   + Fixed the headers 2.16 changes (Submited by Executor)

  Changes on 31.12.2009 by Sascha Willems (SW)
   + Reverted back to old format, using only one file (NewtonImport.pas instead of three)
   + Fixed a wrong dll name in the joint library
   - Note : No header changes in 2.16
  
  Changes on 29.12.2009 by Sascha Willems (SW)
   + Updated to 2.15 Beta
      - NewtonIslandUpdate - Added parameter "world"
	  - NewtonDestroyBodyByExeciveForce - Added const for parameter "contact"
	  - NewtonCollisionDestructor - Added parameter "World"
	  - NewtonBodyIterator - Added parameter "userData"
	  - NewtonJointIterator - Added parameter "userData"
	  - NewtonWorldForEachJointDo - Added parameter "userData"
	  - NewtonWorldForEachBodyInAABBDo - Added parameter "userData"
      - NewtonMeshCreate - Added parameter "world"
	  - NewtonMeshCreatePlane - Added parameter "world", renamed "textureMatrix" to "textureMatrix0" and added parameter "textureMatrix1"
      - NewtonMeshCalculateOOBB - Changed dataytpe for "matrix" from Float to PFloat 	  
   + Updated joint library to 2.15 Beta
      - Added HingeGetJointAngle
      - Added HingeGetPinAxis
      - Added HingeCalculateJointOmega 	  
  
  Changes on 20.11.2009 by Stuart Carey 
   + Updated to 2.11 Beta (2.11 not released. Subject to change)

  Changes on 03.10.2009 by Stuart Carey 
   + Updated to 2.10 Beta

  Changes on 25.09.2009 by Stuart Carey 
   + Updated to 2.09 Beta
   + Added Executor's Joint Library Translation

  Changes on 09.03.2009 by Stuart Carey 
   + Converted to NGD 2.0 Beta

  Changes on 28.06.2006 by Sascha Willems 
   + NewtonBodyGetForceAndTorqueCallback	: Function added
   
  Updated to SDK 1.53 on 26.05.2006 by Sascha Willems
   - NewtonWorldRayCast			        : Changed parameters to new SDK

  Updated to SDK 1.52 on 13.03.2006 by Sascha Willems
   + NewtonWorldForEachBodyInAABBDo             : Function added
   - NewtonCreateConvexHull                     : Added consts to pointer params     

  Updated to SDK 1.5 on 02.01.2006 by Sascha Willems
   x NewtonWorldCollide                         : Removed (no longer in SDK)   
   + NewtonMaterialSetContactNormalAcceleration : Function added               
   + NewtonMaterialSetContactNormalDirection    : Function added               
   + NewtonCollisionPointDistance               : Function added               
   + NewtonCollisionClosestPoint                : Function added               
   + NewtonCollisionCollide                     : Function added               
   - NewtonBodyCoriolisForcesMode               : Corrected spelling (FPC)     
   - NewtonRagDollGetRootBone                   : Commented out (not in DLL)   
   x NewtonBodyGetTotalVolume                   : Removed (renamed in SDK)     
   + NewtonConvexCollisionCalculateVolume       : Function added
   + NewtonConvexCollisionCalculateInertial...  : Function added               
   + NewtonMaterialSetContinuousCollisionMode   : Function added               
   - NewtonUserJointSetRowMinimunFriction       : Corrected spelling           
   - NewtonUserJointSetRowMaximunFriction       : Corrected spelling           
   + NewtonCollisionCollideContinue             : Function added               
   + NewtonBodySetCentreOfMass                  : Function added               
   + NewtonBodyGetCentreOfMass                  : Function added               
   + NewtonUserJointSetRowSpringDamperAcce...   : Function added               
   x NewtonVehicleBalanceTires                  : Removed (no longer in SDK)   
   - NewtonGetBuoyancyPlane                     : Changed parameters to new SDK
   + NewtonSetPlatformArchitecture              : Function added               
   + NewtonCollisionMakeUnique                  : Function added               
   - NewtonVehicle*                             : Changed parameters to new SDK
   + NewtonUserJointAddGeneralRow               : Function added

  Changes on 13.04.2005 by Sascha Willems                                     
   - NewtonAllocMemory                           : Fixed declaration. Was declared    
                                               	  as procedure but should have been  
                                             	  a function returning a pointer.    
                                            	  Thx to Tux for pointing it out.    
  Changes on 03.04.2005 by Sascha Willems                                     
   - Symbol NEWTON_DOUBLE_PRECISION             : Define this when you want to use   
                                            	  Newton with the double precision   
                                           	  dll                                


Updated to SDK 1.31 on 09.01.2005 by Sascha Willems                           
   x NewtonUpVectorCallBack                     : Removed (no longer in SDK)         
   x NewtonUpVectorSetUserCallback        	: Removed (no longer in SDK)         
   - NewtonConstraintCreateUserJoint      	: Changed parameters to new SDK      
   x NewtonUserJointSetUserCallback       	: Removed (no longer in SDK)         
   + NewtonUserJointAddLinearRow;         	: Function added                     
   + NewtonUserJointAddAngularRow         	: Function added                     
   + NewtonUserJointSetRowMinimunFriction 	: Function added                     
   + NewtonUserJointSetRowMaximunFriction 	: Function added                     
   + NewtonUserJointSetRowAcceleration    	: Function added                     
   + NewtonUserJointSetRowStiffness       	: Function added                     
   + NewtonSetSolverModel                 	: Function added                     
   + NewtonSetFrictionModel               	: Function added                     
   + NewtonUserJointGetRowForce           	: Function addes                     
   + NewtonAddBodyImpulse                 	: Declaration fixed                  

 Fixes on 27.11.2004 by Sascha Willems                                         
   - NewtonGetBuoyancyPlane                     : globalSpaceMatrix changed to PFloat
   
 Fixes on 22/23/24/25.11.2004 by Sascha Willems                               
   - NewtonCollisionIterator                    : cdecl was missing                  
   - NewtonCreateSphere                   	: Fixed parameters                   
   - NewtonVehicleTireIsAirBorne          	: Corrected spelling error           
   - NewtonVehicleTireLostSideGrip        	: Corrected spelling error           
   - NewtonVehicleTireLostTraction        	: Corrected spelling error           
   - NewtonRagDollAddBone                 	: Fixed parameters                   
   - NewtonWorldCollide                   	: Added missing "const"s for params  
   - NewtonWorldRayFilterCallback         	: Fixed parameters and return value  
   - NewtonWorldRayCast                   	: Fixed parameters (removed normal)  
   - NewtonBodySetContinuousCollisionMode 	: Corrected spelling error           
   - NewtonConstraintCreateUniversal      	: Corrected spelling error           
   - NewtonJointSetStiffness              	: Corrected spelling error           
   + NewtonGetTimeStep                    	: Function added                     

  Non-Delphi compiler support added on 17.08.2004 by Dominique Louis           
  Newton 1.3 support added on 22.11.2004 by Jon Walton                         

   Conversion completed at 13.08.2004 by Sury                                   

Conversion started at 13.08.2004 by Sury                                     

   