classdef RandomScenario
   properties
      patient
      sensor
      pump
      scenario
   end
   methods
      function CHO, insulin, BG, CGM = get_action(obj,action)
        %todo
        patient_action = scenario.get_action(time);
        basal = pump.basal(action.basal);
        bolus = pump.bolus(action.bolus);
        insulin = basal + bolus;
        CHO = patient_action.meal;
        patient_mdl_act = Action(insulin=insulin, CHO=CHO);

        % State update
        patient.step(patient_mdl_act);

        % next observation
        BG = patient.observation.Gsub;
        CGM = sensor.measure(patient);
      end
      
      function mini_step(obj, action)
         %todo
         patient_action = scenario.get_action(time);
      end
      
      function s = step(obj, action, reward_fun)
        CHO = 0.0;
        insulin = 0.0;
        BG = 0.0;
        CGM = 0.0;

        for _ 1:sample_time
            % Compute moving average as the sample measurements
            tmp_CHO, tmp_insulin, tmp_BG, tmp_CGM = mini_step(action);
            CHO = CHO + tmp_CHO / self.sample_time;
            insulin =insulin + tmp_insulin / self.sample_time;
            BG = BG + tmp_BG / self.sample_time;
            CGM = CGM + tmp_CGM / self.sample_time;

        % Compute risk index
        horizon = 1;
        LBGI, HBGI, risk = risk_index([BG], horizon);

        % Record current action
        CHO_hist.append(CHO);
        insulin_hist.append(insulin);

        % Record next observation
        time_hist.append(self.time)
        BG_hist.append(BG)
        CGM_hist.append(CGM)
        risk_hist.append(risk)
        LBGI_hist.append(LBGI)
        HBGI_hist.append(HBGI)

        % Compute reward, and decide whether game is over
        window_size = int(60 / self.sample_time);
        BG_last_hour = CGM_hist[-window_size:];
        reward = reward_fun(BG_last_hour);
        done = BG < 70 | BG > 350;
        obs = Observation(CGM);

        s = Step(
            observation=obs,
            reward=reward,
            done=done,
            sample_time=sample_time,
            patient_name=patient.name,
            meal=CHO,
            patient_state=patient.state);
        end
      
      function _reset(obj)
          %todo
      end
      
      function reset(obj)
          %todo
      end
      
      function render(obj)
          %todo
      end
      
      function show_history(obj)
          %todo
      end
      
   end
   
end

function patient = pick_patient()
    % found in 'vpatient_params.csv'
    patient = 'adolescent#001';
end

function cgm_sensor_name, cgm_seed = pick_cgm_sensor()
    %found in 'sensor_params.csv'
    cgm_sensor_name = 'Insulet';
    cgm_seed = 0;
end

function insulin_pump_name = pick_insulin_pump()
    % found in 'pump_params.csv'
    insulin_pump_name = 'Dexcom';
end
       
function env = local_build_env(pname)
    patient = T1DPatient.withName(pname) %Todo
    cgm_sensor = CGMSensor.withName(cgm_sensor_name, seed=cgm_seed) %Todo
    insulin_pump = InsulinPump.withName(insulin_pump_name) %Todo
    scen = copy.deepcopy(scenario)                      %Todo
    env = T1DSimEnv(patient, cgm_sensor, insulin_pump, scen)  %Todo
end

function env = build_env()
    patient = pick_patient();
    cgm_sensor_name, cgm_seed = pick_cgm_sensor();
    insulin_pump_name = pick_insulin_pump();
    scenario = RandomScenario; % Started, need finishing...
    env = local_build_env(p); % Started, need finishing
end