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

classdef HardcodedScenario
   properties
     meal_times
     meal_carbs
   end
   methods
      function carbs_added = get_action(obj, t)
        % t is a datetime
        tod = timeofday(t)
        t_sec = seconds(tod)

        if t_sec < 1:
            obj.create_scenario()

        t_min = floor(t_sec / 60.0)

        if ismember(t_min,obj.meal_times,'rows')
            idx = obj.meal_times==t_min;
            carbs_added = obj.meal_carbs(idx)
        else
            carbs_added = 0
        end
      end
      function create_scenario(obj)
        obj.meal_times = {9, 12, 6}
        obj.meal_carbs = {20.,50.,60.}
      end
      function reset()
        obj.create_scenario()
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
        % https://www.mathworks.com/help/matlab/ref/duration.html
        t = obj.scenario.start_time + minutes(obj.patient.t)
      end

      function CHO, insulin, BG, CGM = mini_step(obj, action)
        # current action
        CHO = obj.scenario.get_action(self.time)
        basal = obj.pump.basal(action.basal)
        bolus = obj.pump.bolus(action.bolus)
        insulin = basal + bolus

        # State update
        obj.patient.step(insulin, CHO)

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
        obj.scenario.reset()
        obj._reset()
        CGM = obj.sensor.measure(obj.patient)
        obs = Observation(CGM=CGM)
        Step = containers.Map({"observation","reward","done","sample_time","patient_name","meal","patient_state"},
                       {obs, 0, False, obj.sample_time, obj.patient.name, 0, obj.patient.state})
      end

      function res = show_history(obj)
        res = containers.Map({"Time","BG","CGM","CHO","insulin","LBGI","HBGI","Risk"},
                       {obj.time_hist,obj.BG_hist,obj.CGM_hist,obj.CHO_hist,obj.insulin_hist,obj.LBGI_hist,obj.HBGI_hist,obj.risk_hist})
      end
    end

classdef T1DPatient
   properties
    patient_params
    init_state=None
    t0=0
    last_CHO = 0
    is_eating = False
    last_foodtaken = 0
   end
   methods
      function y = state(obj)
        y = obj._odesolver.y
      end

      function t_ = t(obj)
        t_ = obj._odesolver.t
      end

      function sample_time_ = sample_time(obj)
        sample_time_ = 1
      end

      function step(obj, insulin, CHO)
        % todo
        if CHO > 0. && last_CHO == 0.
            _last_Qsto = obj._odesolver.y(1) + obj._odesolver.y(2)
            obj.last_foodtaken = 0
            obj.is_eating = True
        end

        if obj.is_eating
            obj.last_foodtaken = obj.last_foodtaken + CHO
        end

        if CHO <= 0 and last_CHO > 0
            obj.is_eating = False
        end

        obj.last_CHO = CHO

        [tsol,ysol] = ode45(@(t, x, CHO, insulin, patient_params, _last_Qsto, last_foodtaken) obj.model(t, x, CHO, insulin, patient_params, _last_Qsto, last_foodtaken), t, x, CHO, insulin, patient_params, _last_Qsto, last_foodtaken)
      end

      function y = dxdt = model(obj, t, x, CHO, insulin, patient_params, _last_Qsto, last_foodtaken)
        % put ur code
      end

      function obs observation(obj)
        GM = obj._odesolver.y(13)
        Gsub = GM / obj.patient_params(23) %Vg
        obs = containers.Map({"Gsub"},
                             {Gsub})
      end
      function reset(obj)
        obj.last_CHO = 0
        obj.is_eating = False
        obj.last_foodtaken = 0
      end
    end

classdef CGMSensor
   properties
    cgm_params
    last_CGM = 0
    seed = 0
    sample_time = 0
   end
   methods
      function CGM = measure(obj, patient)
        if mod(patient.t(), obj.sample_time) == 0
            BG = patient.observation.Gsub
            CGM_ = BG
            CGM_ = max(CGM_, obj.cgm_params(7)) %min
            CGM = min(CGM_, obj.cgm_params(8)) %max
            obj._last_CGM = CGM
        else
            CGM = obj.last_CGM
      end
      function reset(obj)
        obj.last_CGM = 0
      end
    end

classdef InsulinPump
   properties
    insulin_pump_params
    U2PMOL = 6000
   end
   methods
      function bol = bolus(obj, amount)
        bol = amount * obj.U2PMOL  % convert from U/min to pmol/min
        bol = round(bol / obj.insulin_pump_params(3)) * obj.insulin_pump_params(3) %'inc_bolus'
        bol = bol / obj.U2PMOL     % convert from pmol/min to U/min
        bol = min(bol, obj.insulin_pump_params(2)) %'max_bolus'
        bol = max(bol, obj.insulin_pump_params(1)) %'min_bolus'
      end
      function bas = basal(obj, amount)
        bas = amount * obj.U2PMOL  % convert from U/min to pmol/min
        bas = round(bas / obj.insulin_pump_params(6)) * obj.insulin_pump_params(6) %'inc_basal'
        bas = bas / obj.U2PMOL     % convert from pmol/min to U/min
        bas = min(bas, obj.insulin_pump_params(5)) %'max_basal'
        bas = max(bas, obj.insulin_pump_params(4)) %'min_basal'
      end
    end

function patient, patient_params = pick_patient()
    patient = 'adolescent#001';

    %x0_1,x0_ 2,x0_ 3,x0_ 4,x0_ 5,x0_ 6,x0_ 7,x0_ 8,x0_ 9,x0_10,x0_11,x0_12,x0_13,BW,EGPb,Gb,Ib,kabs,kmax,kmin,b,d,Vg,Vi,Ipb,Vmx,Km0,k2,k1,p2u,m1,m5,CL,HEb,m2,m4,m30,Ilb,ki,kp2,kp3,f,Gpb,ke1,ke2,Fsnc,Gtb,Vm0,Rdb,PCRb,kd,ksc,ka1,ka2,

    patient_params = {0,0,0,250.621836,176.506559902,4.697517762,0,97.554,97.554,3.19814917262,57.951224472,93.2258828462,250.621836,68.706,3.3924,149.02,97.554,0.091043,0.015865,0.0083338,0.83072,0.32294,1.6818,0.048153,4.697517762,0.074667,260.89,0.067738,0.057252,0.021344,0.15221,0.029902,0.8571,0.6,0.259067825939,0.103627130376,0.228315,3.19814917262,0.0088838,0.023318,0.023253,0.9,250.621836,0.0005,339,1,176.506559902,5.92854753098,3.3924,0.0227647295665,0.0185,0.056,0.0025,0.0115,90000,1.21697571391,57.951224472,93.2258828462,11.5048231338,0};

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
