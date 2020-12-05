classdef T1DPatient
   properties
    params;
    t0=0;
    last_CHO = 0;
    is_eating = 0; %0 = false, 1 = true
    last_foodtaken = 0;
    current_bg;
    current_t;
   end
   methods
      function y = state(obj)
        y = obj.current_bg;
      end

      function t_ = t(obj)
        t_ = obj.current_t;
      end

      function sample_time_ = sample_time(obj)
        sample_time_ = 1;
      end

      function step(obj, insulin, CHO)
        if CHO > 0. && obj.last_CHO == 0.
            last_Qsto = obj.current_bg(1) + obj.current_bg(2);
            obj.last_foodtaken = 0;
            obj.is_eating = 1;
        end

        if obj.is_eating == 1
            obj.last_foodtaken = obj.last_foodtaken + CHO;
        end

        if CHO <= 0 && obj.last_CHO > 0
            obj.is_eating = 0;
        end

        obj.last_CHO = CHO;

        [obj.current_t, obj.current_bg] = ode45(@(t, x, CHO, insulin, params, last_Qsto, last_foodtaken) obj.model(t, x, CHO, insulin, params, last_Qsto, last_foodtaken), t, x, CHO, insulin, obj.params, last_Qsto, obj.last_foodtaken);
      end

      function dxdt = model(obj, x, CHO, insulin, params, last_Qsto, last_foodtaken)
        dxdt = zeros(1, 13);
        d = CHO * 1000; %g -> mg
        insulin = insulin * 6000 / params(BW); %U/min -> pmol/kg/min
        basal = params(u2ss) * params(BW) / 6000; %U/min

        %glucose in stomach
        Qsto = x(1) + x(2);
        Dbar = last_Qsto + last_foodtaken;

        %stomach solid
        dxdt(1) = -params(kmax) * x(1) + params(d);

        if Dbar > 0
            aa = 5/2/(1-params(b))/Dbar;
            cc = 5/2/params(d)/Dbar;
            kgut = params(kmin) + (params(kmax) - params(kmin)) /2*tanh(aa*(Qsto - params(b) * Dbar))...
                -tanh(cc*(Qsto - params(d) * Dbar) + 2);
        else
            kgut = params(kmax);
        end
        %stomach liquid
        dxdt(2) = params(kmax) * x(1) - x(2) * kgut;

        %intestine
        dxdt(3) = kgut * x(2) - params(kabs) * x(3);

        %glucose rate of appearance (Ra)
        Ra = params(f) * params(kabs) * x(3) / params(BW);

        %endogenous glucose production
        EGPt = params(kp1) - params(kp2) * x(4) - params(kp3) * x(9);

        %glucose utilization
        Uiit = params(Fsnc);

        %renal excretion
        if x(4) > params(ke2)
            Et = params(ke1) * (x(4) - params(ke2));
        else
            Et = 0;
        end
        %glucose kinetics
        dxdt(4) = max(EGPt, 0) + Ra - Uiit - Et - params(k1) * x(4) + params(k2) * x(5);
        dxdt(4) = (x(4) >= 0) * dxdt(4);

        Vmt = params(Vm0) + params(Vmx) * x(7);
        Kmt = params(Km0);
        Uidt = Vmt * x(5) / (Kmt + x(5));
        dxdt(5) = -Uidt + params(k1) * x(4) - params(k2) * x(5);
        dxdt(5) = (x(5) >= 0) * dxdt(5);

        %insulin kinetics
        dxdt(6) = -(params(m2) + params(m4))*x(6) + params(m1) * ...
            x(10)+params(ka1) * x(11)+params(ka2) * x(12);
        It = x(6)/params(Vi);
        dxdt(6) = (x(6) >= 0)*dxdt(5);

        %insulin action-glucose utilization
        dxdt(7) = -params(p2u)*x(7)+params(p2u)*(It - params(Ib));

        %insulin action-production
        dxdt(8) = -params(ki)*(x(8) - It);
        dxdt(9) = -params(ki)*(x(9) - x(8));

        %insulin in the liver (pmol/kg)
        dxdt(10) = -(params(m1) + params(m30)) * x(10) + params(m2) * x(6);
        dxdt(10) = (x(10) >= 0) * dxdt(10);

        %subcutaneous insulin kinetics
        dxdt(11) = insulin - (params(ka1) + params(kd)) * x(11);
        dxdt(11) = (x(11) >= 0) * dxdt(11);

        dxdt(12) = kd * x(11) - ka2 * x(12);
        dxdt(12) = (x(12) >= 0) * dxdt(12);

        %subcutaneous glucose
        dxdt(13) = -params(ksc) * x(13) + params(ksc) * x(14);
        dxdt(13) = (x(13) >= 0 ) * dxdt(13);
        
        dxdt
        x
      end

      function obs = observation(obj)
       GM = obj.current_bg(13);
       Gsub = GM / obj.params(Vg);
       obs = containers.Map("Gsub", Gsub);
      end
      
      function reset(obj)
        obj.last_CHO = 0;
        obj.is_eating = 0;
        obj.last_foodtaken = 0;
      end
   end
end
