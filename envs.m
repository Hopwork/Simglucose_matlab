function tup = risk_index(BG, horizon)
    % Todo: convert this to matlab
    BG_to_compute = BG(-horizon:)
    fBG = 1.509 * (log(BG_to_compute)**1.084 - 5.381)
    rl = 10 * fBG(fBG < 0)**2
    rh = 10 * fBG(fBG > 0)**2
    %LBGI = np.nan_to_num(np.mean(rl))
    %HBGI = np.nan_to_num(np.mean(rh))
    LBGI = mean(rl)
    HBGI = mean(rh)
    RI = LBGI + HBGI
    tup = (LBGI, HBGI, RI)
end

function riskDiff = risk_diff(BG_last_hour)
    if length(BG_last_hour) < 2
        riskDiff = 0
    else
        A = risk_index([BG_last_hour[-1]], 1)
        _, _, risk_current = A
        B = risk_index([BG_last_hour[-2]], 1)
        _, _, risk_prev = B
        riskDiff = risk_prev - risk_current
    end
end

classdef T1DSimEnv
   properties
      patient
      sensor
      pump
      scenario
   end
   methods
      function t = time(obj)
        % t is a duration object
        % https://www.mathworks.com/help/matlab/ref/duration.html
        t = obj.scenario.start_time + minutes(obj.patient.t)
      end

      function CHO, insulin, BG, CGM = mini_step(obj, action)
        # current action
        patient_action = obj.scenario.get_action(self.time)
        basal = obj.pump.basal(action.basal)
        bolus = obj.pump.bolus(action.bolus)
        insulin = basal + bolus
        CHO = patient_action.meal
        patient_mdl_act = Action(insulin=insulin, CHO=CHO)

        # State update
        obj.patient.step(patient_mdl_act)

        # next observation
        BG = obj.patient.observation.Gsub
        CGM = obj.sensor.measure(obj.patient)
      end

      function Step = step(obj, action, reward_fun=risk_diff)
        CHO = 0.0
        insulin = 0.0
        BG = 0.0
        CGM = 0.0

        for _ = 1:round(obj.sample_time)
            % Compute moving average as the sample measurements
            tmp_CHO, tmp_insulin, tmp_BG, tmp_CGM = obj.mini_step(action)
            CHO += tmp_CHO / obj.sample_time
            insulin += tmp_insulin / obj.sample_time
            BG += tmp_BG / obj.sample_time
            CGM += tmp_CGM / obj.sample_time

        % Compute risk index
        horizon = 1
        LBGI, HBGI, risk = risk_index([BG], horizon)

        % Record current action
        obj.CHO_hist = [obj.CHO_hist, CHO]
        obj.insulin_hist = [obj.insulin_hist, insulin]

        % Record next observation
        obj.time_hist = [obj.time_hist, self.time]
        obj.BG_hist = [obj.BG_hist, BG] 
        obj.CGM_hist = [obj.CGM_hist, CGM]
        obj.risk_hist = [obj.risk_hist, risk]
        obj.LBGI_hist = [obj.LBGI_hist, LBGI]
        obj.HBGI_hist = [obj.HBGI_hist, HBGI]

        # Compute reward, and decide whether game is over
        window_size = int(60 / obj.sample_time)
        BG_last_hour = obj.CGM_hist[-window_size:]
        reward = reward_fun(BG_last_hour)
        done = (BG < 70)|(BG > 350)
        obs = containers.Map({"CGM"},
                             {CGM})
        Step = containers.Map({"observation","reward","done","sample_time","patient_name","meal","patient_state"},
                       {obs, reward, done, obj.sample_time, obj.patient.name, CHO, obj.patient.state})
      end

      function _reset(obj)
        obj.sample_time = obj.sensor.sample_time
        obj.viewer = None

        BG = obj.patient.observation.Gsub
        horizon = 1
        LBGI, HBGI, risk = risk_index({BG}, horizon)
        CGM = obj.sensor.measure(obj.patient)
        obj.time_hist = {obj.scenario.start_time}
        obj.BG_hist = {BG}
        obj.CGM_hist = {CGM}
        obj.risk_hist = {risk}
        obj.LBGI_hist = {LBGI}
        obj.HBGI_hist = {HBGI}
        obj.CHO_hist = {}
        obj.insulin_hist = {}
      end

      function Step = reset(obj)
        obj.patient.reset()
        obj.sensor.reset()
        obj.pump.reset()
        obj.scenario.reset()
        obj._reset()
        CGM = obj.sensor.measure(obj.patient)
        obs = Observation(CGM=CGM)
        Step = containers.Map({"observation","reward","done","sample_time","patient_name","meal","patient_state"},
                       {obs, 0, False, obj.sample_time, obj.patient.name, 0, obj.patient.state})
      end

      function render(obj)
        %todo, if wanted
      end

      function show_history(obj)
        %todo, if wanted
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
