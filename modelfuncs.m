clear;
clc;

D=0.001;
target=140;
controller = PIDController;
controller.P = 0.001;
controller.I = 0.00001;
controller.D = 0.001;

RUNME(controller);


function RUNME(controller)

    scenario = HardcodedScenario;

    patient = 'adolescent#001';
    patient_key = {'x0_1','x0_2','x0_3','x0_4','x0_5','x0_6','x0_7','x0_8','x0_9','x0_10','x0_11','x0_12','x0_13','BW','EGPb','Gb','Ib','kabs','kmax','kmin','b','d','Vg','Vi','Ipb','Vmx','Km0','k2','k1','p2u','m1','m5','CL','HEb','m2','m4','m30','Ilb','ki','kp2','kp3','f','Gpb','ke1','ke2','Fsnc','Gtb','Vm0','Rdb','PCRb','kd','ksc','ka1','ka2', 'dosekempt',	'u2ss',	'isc1ss',	'isc2ss',	'kp1',	'patient_history'};
    patient_params_l = [0	0	0	250.621836	176.506559902	4.697517762	0	97.554	97.554	3.19814917262	57.951224472	93.2258828462	250.621836	68.706	3.3924	149.02	97.554	0.091043	0.015865	0.0083338	0.83072	0.32294	1.6818	0.048153	4.697517762	0.074667	260.89	0.067738	0.057252	0.021344	0.15221	0.029902	0.8571	0.6	0.259067825939	0.103627130376	0.228315	3.19814917262	0.0088838	0.023318	0.023253	0.9	250.621836	0.0005	339	1	176.506559902	5.92854753098	3.3924	0.0227647295665	0.0185	0.056	0.0025	0.0115	90000	1.21697571391	57.951224472	93.2258828462	11.5048231338	0];
    patient_params = containers.Map(patient_key, patient_params_l);
    patient_params
    
    
    cgm_sensor_name = 'Dexcom';
    cgm_params = [0.7,-0.5444,15.9574,1.6898,-5.47,3.0,39.0,600.0];
    cgm_seed = 0;
    
    insulin_pump_name = 'Insulet';
    insulin_pump_params = [0.0,30.0,0.05,0.0,30.0,0.05,1.0];
    
    patient = T1DPatient;
    patient.params = patient_params;
    patient.name = 0;
   % patient. = patient_params(3:16);
    patient.reset();

    cgm_sensor = CGMSensor;
    cgm_sensor.cgm_params = cgm_params;
    cgm_sensor.seed = cgm_seed;
    
    fprintf("SAMPLE TIME")
    cgm_params(6)
    cgm_sensor.sample_time = cgm_params(6);
    
    insulin_pump = InsulinPump;
    insulin_pump.insulin_pump_params = insulin_pump_params;
   
    env = envs;
    env.patient = patient; 
    env.sensor = cgm_sensor; 
    env.pump = insulin_pump; 
    env.scenario = scenario;
    env.sample_time = 8;
    patient

    simObj = SimObj;
    simObj.controller = controller;
    simObj.env = env;

    simObj.simulate();
    results = simObj.results();
    plot(results);
end


