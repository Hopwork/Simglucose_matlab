classdef envs
   properties
      patient
      sensor
      pump
      scenario
      sample_time
   end
   methods
      function t = time(obj)
        % https://www.mathworks.com/help/matlab/ref/duration.html
        t = obj.scenario.start_time + minutes(obj.patient.t);
      end

      function [CHO, insulin, BG, CGM] = mini_step(obj, action)
        %current action
        CHO = obj.scenario.get_action(self.time);
        basal = obj.pump.basal(action.basal);
        bolus = obj.pump.bolus(action.bolus);
        insulin = basal + bolus;

        %State update
        obj.patient.step(insulin, CHO);

        %next observation
        BG = obj.patient.observation.Gsub;
        CGM = obj.sensor.measure(obj.patient);
      end

      function Step = step(obj, action)                        
          CHO = 0.0;
          insulin = 0.0;
          BG = 0.0;
          CGM = 0.0;

        for i = 1:round(obj.sample_time)
            % Compute moving average as the sample measurements
            [tmp_CHO, tmp_insulin, tmp_BG, tmp_CGM] = obj.mini_step(action);  
            CHO = CHO + tmp_CHO / obj.sample_time;
            insulin = insulin + tmp_insulin / obj.sample_time;
            BG = BG + tmp_BG / obj.sample_time;
            CGM = CGM + tmp_CGM / obj.sample_time;
        end
        
        % Compute risk index
        horizon = 1;
        [LBGI, HBGI, risk] = risk_index(BG, horizon);

        % Record current action
        obj.CHO_hist = [obj.CHO_hist CHO];
        obj.insulin_hist = [obj.insulin_hist insulin];

        % Record next observation
        obj.time_hist = [obj.time_hist self.time];
        obj.BG_hist = [obj.BG_hist BG] ;
        obj.CGM_hist = [obj.CGM_hist CGM];
        obj.risk_hist = [obj.risk_hist risk];
        obj.LBGI_hist = [obj.LBGI_hist LBGI];
        obj.HBGI_hist = [obj.HBGI_hist HBGI];

        %Compute reward, and decide whether game is over
        window_size = int(60 / obj.sample_time);
        BG_last_hour = obj.CGM_hist(end-window_size:end);                   %%%%%is this correct for neg index
        reward = risk_diff(BG_last_hour);
        done = (BG < 70)|(BG > 350);
        obs = containers.Map("CGM",CGM);                                    
        step_key = ["observation","reward","done","sample_time","patient_name","meal","patient_state"];
        step_vals = [obs, reward, done, obj.sample_time, obj.patient.name, CHO, obj.patient.state];
        Step = containers.Map(step_key, step_vals);
      end

      function reset_(obj)
        obj.sample_time = obj.sensor.sample_time;
        %obj.viewer = None;

        BG = obj.patient.observation.Gsub;
        horizon = 1;
        LBGI, HBGI, risk = risk_index({BG}, horizon);
        CGM = obj.sensor.measure(obj.patient);
        obj.time_hist = {obj.scenario.start_time};
        obj.BG_hist = {BG};
        obj.CGM_hist = {CGM};
        obj.risk_hist = {risk};
        obj.LBGI_hist = {LBGI};
        obj.HBGI_hist = {HBGI};
        obj.CHO_hist = {};
        obj.insulin_hist = {};
      end

      function Step = reset(obj)                                            
        obj.patient.reset();
        obj.sensor.reset();
        obj.scenario.reset();
        obj.reset_();
        CGM = obj.sensor.measure(obj.patient);
        obs = containers.Map(["CGM"],[CGM]);                                 
        step_key2 = ["observation","reward","done","sample_time","patient_name","meal","patient_state"];
        step_vals2 = [obs, 0, False, obj.sample_time, obj.patient.name, 0, obj.patient.state];
        Step = containers.Map(step_key2, step_vals2);
      end

      function res = show_history(obj)
          res_key = ["Time","BG","CGM","CHO","insulin","LBGI","HBGI","Risk"];
          res_vals = [obj.time_hist, obj.BG_hist, obj.CGM_hist, obj.CHO_hist, obj.insulin_hist, obj.LBGI_hist, obj.HBGI_hist, obj.risk_hist];
          res = containers.Map(res_key, res_vals);
      end      
   end
end

function tup = risk_index(BG, horizon)
    BG_to_compute = BG(-horizon:end);
    fBG = 1.509 * (log(BG_to_compute)^1.084 - 5.381);
    rl = 10 * fBG(fBG < 0)^2;
    rh = 10 * fBG(fBG > 0)^2;
    LBGI = mean(rl);
    HBGI = mean(rh);
    RI = LBGI + HBGI;
    tup = [LBGI, HBGI, RI];
end

function riskDiff = risk_diff(BG_last_hour)
    if length(BG_last_hour) < 2
        riskDiff = 0;
    else
        A = risk_index(BG_last_hour(-1), 1);
        aaa, bbb, risk_current = A;
        B = risk_index(BG_last_hour(-2), 1);
        ccc, ddd, risk_prev = Bl;
        riskDiff = risk_prev - risk_current;
    end
end
