

% TODO: import everything from envs
% import controller


classdef SimObj
   properties
      controller
      env
      sim_time
   end
   methods
      function simulate(obj)
         %todo
         Step = obj.env.reset();
         while env.time < env.scenario.start_time + sim_time
             action = controller.policy(obs, Step);
             Step = env.step(action);
      end
      function r = results(obj)
         env.show_history()
      end
      function reset(obj)
        obj.env.reset()
        obj.controller.reset()
      end
   end
end

function plot(results)
    %todo
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