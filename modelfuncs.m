function patient, patient_params = pick_patient()
    patient = 'adolescent#001';

    patient_key = {'x0_1','x0_2','x0_3','x0_4','x0_5','x0_6','x0_7','x0_8','x0_9','x0_10','x0_11','x0_12','x0_13','BW','EGPb','Gb','Ib','kabs','kmax','kmin','b','d','Vg','Vi','Ipb','Vmx','Km0','k2','k1','p2u','m1','m5','CL','HEb','m2','m4','m30','Ilb','ki','kp2','kp3','f','Gpb','ke1','ke2','Fsnc','Gtb','Vm0','Rdb','PCRb','kd','ksc','ka1','ka2'};
    patient_params = [0,0,0,250.621836,176.506559902,4.697517762,0,97.554,97.554,3.19814917262,57.951224472,93.2258828462,250.621836,68.706,3.3924,149.02,97.554,0.091043,0.015865,0.0083338,0.83072,0.32294,1.6818,0.048153,4.697517762,0.074667,260.89,0.067738,0.057252,0.021344,0.15221,0.029902,0.8571,0.6,0.259067825939,0.103627130376,0.228315,3.19814917262,0.0088838,0.023318,0.023253,0.9,250.621836,0.0005,339,1,176.506559902,5.92854753098,3.3924,0.0227647295665,0.0185,0.056,0.0025,0.0115,90000,1.21697571391,57.951224472,93.2258828462,11.5048231338,0];
    params = containers.Map(patient_key, patient_params);
    
end

function cgm_sensor_name, cgm_params, cgm_seed = pick_cgm_sensor()
    % PACF,gamma,lambda,delta,xi,sample_time,min,max
    cgm_sensor_name = 'Dexcom';
    cgm_params = {0.7,-0.5444,15.9574,1.6898,-5.47,3.0,39.0,600.0};
    cgm_seed = 0;
end

function insulin_pump_name, insulin_pump_params = pick_insulin_pump()
    % min_bolus,max_bolus,inc_bolus,min_basal,max_basal,inc_basal,sample_time
    insulin_pump_name = 'Insulet';
    insulin_pump_params = {0.0,30.0,0.05,0.0,30.0,0.05,1.0};
end
       
function env = local_build_env(pname, scenario)

    patient, patient_params = pick_patient();
    cgm_sensor_name, cgm_params, cgm_seed = pick_cgm_sensor();
    insulin_pump_name, insulin_pump_params = pick_insulin_pump();
    
    patient = T1DPatient(patient_params, init_state = patient_params(3:16))
    patient.reset()

    cgm_sensor = CGMSensor(cgm_params, seed=cgm_seed, sample_time = cgm_params(6))
    insulin_pump = InsulinPump(insulin_pump_params)
    env = T1DSimEnv(patient, cgm_sensor, insulin_pump, scenario)
end

function env = build_env()
    scenario = HardcodedScenario();
    env = local_build_env(scenario);
end

function tup = risk_index(BG, horizon)
    % Todo: convert this to matlab
    BG_to_compute = BG(-horizon:end);
    fBG = 1.509 * (log(BG_to_compute)^1.084 - 5.381);
    rl = 10 * fBG(fBG < 0)^2;
    rh = 10 * fBG(fBG > 0)^2;
    %LBGI = np.nan_to_num(np.mean(rl))
    %HBGI = np.nan_to_num(np.mean(rh))
    LBGI = mean(rl);
    HBGI = mean(rh);
    RI = LBGI + HBGI;
    tup = (LBGI, HBGI, RI);
end

function riskDiff = risk_diff(BG_last_hour)
    if length(BG_last_hour) < 2
        riskDiff = 0;
    else
        A = risk_index([BG_last_hour[-1]], 1);
        aaa, bbb, risk_current = A;
        B = risk_index([BG_last_hour[-2]], 1);
        ccc, ddd, risk_prev = Bl;
        riskDiff = risk_prev - risk_current;
    end
end

function simObj = create_sim_instance(controller)
    env = build_env();    
    simObj = SimObj(controller, env);
end  

function results = sim(sim_object)
    sim_object.simulate();
    results = sim_object.results()
end

function RUNME(controller)
    sim_inst = create_sim_instance(controller=controller);
    results = sim(sim_inst);
    plot(results);
end

pid_controller = PIDController(P=0.001, I=0.00001, D=0.001, target=140)
RUNME(pid_controller)
