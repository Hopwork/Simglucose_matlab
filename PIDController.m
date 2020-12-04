classdef PIDController
   properties
      P
      I
      D
      target
      integrated_state = 0
      prev_state = 0
   end
   methods
      function action = policy(obj, Step)
        sample_time = Step('sample_time');
        obs = Step('obs');
        reward = Step('reward');
        done = Step('done');

        bg = obs('CGM');
        control_input = obj.P * (bg - obj.target) + obj.I * obj.integrated_state + obj.D * (bg - obj.prev_state) / sample_time;

        %update the states
        obj.prev_state = bg;
        obj.integrated_state =  obj.integrated_state + (bg - self.target) * sample_time;

        action = containers.Map(["basal","bolus"],[control_input,0]);
      end
      function reset(obj)
        obj.integrated_state = 0;
        obj.prev_state = 0;
      end
   end
end 
