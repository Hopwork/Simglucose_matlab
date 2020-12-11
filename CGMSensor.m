classdef CGMSensor
   properties
    cgm_params;
    last_CGM = 0;
    seed = 0;
    sample_time = 0;
   end
   methods
      function CGM = measure(obj, patient)
          patient.t
          obj.sample_time
          p = mod(patient.t, obj.sample_time)
        if  p == 0
            BG = patient.observation.Gsub;
            CGM_ = BG;
            CGM_ = max(CGM_, obj.cgm_params(7)); %min
            CGM = min(CGM_, obj.cgm_params(8)); %max
            obj.last_CGM = CGM;
        else
            CGM = obj.last_CGM;
        end
      end
      function reset(obj)
        obj.last_CGM = 0;
      end
    end
end
