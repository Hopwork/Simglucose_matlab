%Todo; convert to matlab

classdef SimObj
   properties
      env
      controller
   end
   methods
      function simulate(obj)
         %todo
         obs, reward, done, info = env.reset();   %todo in envs
         while env.time < env.scenario.start_time + sim_time:
             action = controller.policy(obs, reward, done, info);  %todo in envs
             obs, reward, done, info = env.step(action);   %todo in envs
      end
      function r = results(obj)
         %todo
         env.show_history()
      end
   end
end
