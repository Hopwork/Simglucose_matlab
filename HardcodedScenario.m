classdef HardcodedScenario
   properties
     meal_times
     meal_carbs
   end
   methods
      function carbs_added = get_action(obj, t)
        % t is a datetime
        tod = timeofday(t);
        t_sec = seconds(tod);

        if t_sec < 1
            obj.create_scenario();
        end
        t_min = floor(t_sec / 60.0);

        if ismember(t_min,obj.meal_times,'rows')
            idx = obj.meal_times==t_min;
            carbs_added = obj.meal_carbs(idx);
        else
            carbs_added = 0
        end
      end
      function create_scenario(obj)
        obj.meal_times = {9, 12, 6};
        obj.meal_carbs = {20.,50.,60.};
      end
      function reset()
        obj.create_scenario()
      end
   end
end
