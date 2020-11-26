
function plot(results)
    %todo
end
    
function simObj = create_sim_instance(controller)
    env = build_envs(scenario);    
    simObj = SimObj(controller, env);
end  

function results = sim(sim_object)
    sim_object.simulate();
    sim_object.save_results();
    results = sim_object.results();
end

%do everything!
function RUNME(controller)
    sim_inst = create_sim_instance(controller=controller);
    results = sim(sim_inst);
    plot(results);
end
