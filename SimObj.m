classdef SimObj
   properties
      controller;
      env;
      sim_time;
   end
   methods
      function simulate(obj)
         Step = obj.env.reset();
         while env.time < (env.scenario.start_time + sim_time)
             action = controller.policy(obs, Step);
             Step = env.step(action);
         end
      end 
      function r = results(obj)
         env.show_history();
      end
      function reset(obj)
        obj.env.reset();
        obj.controller.reset();
      end
   end
end

