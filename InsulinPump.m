classdef InsulinPump
   properties
    insulin_pump_params
    U2PMOL = 6000
   end
   methods
      function bol = bolus(obj, amount)
        bol = amount * obj.U2PMOL;  % convert from U/min to pmol/min
        bol = round(bol / obj.insulin_pump_params(3)) * obj.insulin_pump_params(3); %'inc_bolus'
        bol = bol / obj.U2PMOL;     % convert from pmol/min to U/min
        bol = min(bol, obj.insulin_pump_params(2)); %'max_bolus'
        bol = max(bol, obj.insulin_pump_params(1)); %'min_bolus'
      end
      function bas = basal(obj, amount)
        bas = amount * obj.U2PMOL;  % convert from U/min to pmol/min
        bas = round(bas / obj.insulin_pump_params(6)) * obj.insulin_pump_params(6); %'inc_basal'
        bas = bas / obj.U2PMOL;     % convert from pmol/min to U/min
        bas = min(bas, obj.insulin_pump_params(5)); %'max_basal'
        bas = max(bas, obj.insulin_pump_params(4)); %'min_basal'
      end
    end
end

